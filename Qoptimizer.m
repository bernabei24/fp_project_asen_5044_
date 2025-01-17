clear;
clc;
close all;

load("cooplocalization_finalproj_KFdata.mat");  % Assuming Qtrue is defined here and it's global or loaded
% Number of elements in the Q matrix
n = size(Qtrue, 1);  % Assuming Qtrue is used to define the size
numVars = n * (n + 1) / 2;  % Number of unique elements in a symmetric matrix

% Set up GA
options = optimoptions('ga', 'Display', 'iter', 'UseParallel', true, 'FitnessLimit', 0);

% Define the initial range for Q elements
lb = zeros(numVars, 1);  % Lower bounds
ub = 0.5 * ones(numVars, 1);  % Upper bounds, adjust based on your knowledge

% Modify the GA call to include 'n' in the objective function call through an anonymous function
[Qvec_opt, fval] = ga(@(Qvec) objfun(Qvec, n), numVars, [], [], [], [], lb, ub, [], options);

% Define the objective function to include 'n'
function f = objfun(Qvec, n)
    Q = decodeQ(Qvec, n);
    f = calculateErrorforQ(Q);
end

function Q = decodeQ(Qvec, n)
    % Decode vector to symmetric matrix
    Q = zeros(n, n);
    idx = tril(true(n, n));
    Q(idx) = Qvec;
    Q = Q + triu(Q', 1);
end

%initial conditions
function total_rmse = calculateErrorforQ(Qvec)

h = waitbar(0, 'Please wait...');  % Initialize the progress bar
n = sqrt(numel(Qvec));
Q_filter = reshape(Qvec, [n, n]);
Q_filter = (Q_filter + Q_filter') / 2;

Qtrue =diag([0.001, 0.001, 0.01, 0.001, 0.001, 0.01]);
Rtrue = diag([0.0225, 64, 0.04, 36, 36]);
tvec = 0:0.1:100;
total_rmse = 0;
for seed = 1:10
    L = 0.5; %m
    Eg_init = 10; %m
    Ng_init = 0; %m
    thetag_init = pi/2; %rad
    vg_init = 2; %m/s
    phi_init = -pi/18; %rad
    Ea_init = -60; %m
    Na_init = 0; %m
    thetaa_init = -pi/2; %rad
    va_init = 12; %m/s
    omegaa_init = pi/25; %rad/s
    dt = 0.1; %sec

    eigenvaluesQ = eig(Qtrue);
    rng(seed); % for reproduceability
    if all(eigenvaluesQ > 0)
        %disp('The matrix Q is positive definite.');

        % Perform the Cholesky decomposition
        LowerQ = chol(Qtrue, 'lower');

        % Generate a matrix of standard normal random variables

        ZQ = randn(6, 1001);

        % Multiply by the Cholesky factor to get the random vectors with covariance Q
        w_k = LowerQ * ZQ;

    else
        %disp('The matrix Q is not positive definite.');
    end

    %GENERATE RANDOM MEASUREMENT NOISE VECTORS
    eigenvaluesR = eig(Rtrue);
    if all(eigenvaluesR > 0)
        %disp('The matrix R is positive definite.');

        % Perform the Cholesky decomposition
        LowerR = chol(Rtrue, 'lower');

        % Generate a matrix of standard normal random variables

        ZR = randn(5, 1001);

        % Multiply by the Cholesky factor to get the random vectors with covariance Q
        v_k = LowerR * ZR;

    else
        %disp('The matrix R is not positive definite.');
    end

    %constructing initial vectors
    perturb_x0 = [0; 1; 0; 0; 0; 0.1];
    x_init = [Eg_init Ng_init thetag_init Ea_init Na_init thetaa_init]';
    u_init = [vg_init phi_init va_init omegaa_init]';

    %Define input
    u_func = @(t, x) u_init; % Constant control input
    w_func = @(t) w_k(:, min(floor(t / 0.1) + 1, size(w_k, 2)));


    % Define the nonlinear dynamics
    dynamics_noise = @(t, x) x_dotODE45noise(t, x, u_func, w_func, L); %for truth model
    dynamics_nominal = @(t, x) x_dotODE45(t, x, u_func,L); %for nominal trajectory

    % solve nominal trajectory with no perturbations
    [t, x_true] = ode45(dynamics_noise, tvec, x_init);
    [t, x_nominal] = ode45(dynamics_nominal, tvec, x_init); %perturbation not added


    % Wrap the angles theta_g (x(3,:)) and theta_a (x(6,:)) to [-pi, pi]
    x_true(:, 3) = mod(x_true(:, 3) + pi, 2*pi) - pi;  % Wrap theta_g (ground heading)
    x_true(:, 6) = mod(x_true(:, 6) + pi, 2*pi) - pi;  % Wrap theta_a (air heading)

    x_nominal(:, 3) = mod(x_nominal(:, 3) + pi, 2*pi) - pi;  % Wrap theta_g (ground heading)
    x_nominal(:, 6) = mod(x_nominal(:, 6) + pi, 2*pi) - pi;  % Wrap theta_a (air heading)


    % find total measurement vector
    y_true = get_Y_noise(x_true,v_k');
    y_nom = get_Y(x_nominal);

    % Wrap the angles gamma_ag and gamma_ga to [-pi, pi]
    y_true(:, 1) = mod(y_true(:, 1) + pi, 2*pi) - pi;  % Wrap gamma_ag
    y_true(:, 3) = mod(y_true(:, 3) + pi, 2*pi) - pi;  % Wrap gamme_ga

    % Assuming y_true and y_nom are your matrices, each of size 1001x5
    y_true(:, 1) = wrapToPi(y_true(:, 1));  % Wrap the first column (angles) of y_true
    y_true(:, 3) = wrapToPi(y_true(:, 3));  % Wrap the third column (angles) of y_true

    y_nom(:, 1) = wrapToPi(y_nom(:, 1));    % Wrap the first column (angles) of y_nom
    y_nom(:, 3) = wrapToPi(y_nom(:, 3));    % Wrap the third column (angles) of y_nom


    %INITIALIZING FOR LKF LOOP
    %pretty sure this is what gamme looks like although not positive
    gamma = eye(size(x_true,2));
    omega_matrix = dt * gamma;

    %for testing on real data else, comment out
    % y_true(2:end,:) = ydata(:,2:end)';
    % y_true(1,:) = y_nom(1,:);

    dely = y_true - y_nom;

    % Apply wrapToPi only to the 1st and 3rd columns of dely
    dely(:, 1) = wrapToPi(dely(:, 1));  % Wrap the 1st column
    dely(:, 3) = wrapToPi(dely(:, 3));  % Wrap the 3rd column

    delx_plus = zeros(6,1001);
    delx_minus = zeros(6,1001);
    P_plus = zeros(6,6,1001);
    P_minus = zeros(6,6,1001);
    K = zeros(6,5,1001);

    % delx_plus(:,1) = zeros(6,1); %adjustable
    % P_plus(:,:,1) = zeros(6,6); %adjustable

    [del_x_0,P_plus_0] = get_init_conditions(dely,x_nominal,u_init,dt,Rtrue,10);

    delx_plus(:,1) = del_x_0; %adjustable
    P_plus(:,:,1) = P_plus_0; %adjustable
    dely_diff = zeros(5,1001);
    dely_predict = zeros(5,1001);


    %Compute jacobians at each time step from nominal trajectory
    for k = 1:1000 %k=1 represents t = 0
        % Use CT jacobians to find A and B at t = t_k and nom[k]
        A_nom_k = get_Abar(u_init, x_nominal(k, :)');
        B_nom_k = get_Bbar(u_init, x_nominal(k, :)', L);
        C_nom_k = get_Cbar(x_nominal(k+1, :)'); %need H_k+1 not H_k

        % Eulerized estimate of DT Jacobians
        F_k = eye(6) + dt * A_nom_k;
        G_k = dt * B_nom_k;
        H_k_plus_1 = C_nom_k;%need H_k+1 not H_k

        %LINEAR KALMAN FILTER

        %time update/prediction step for time k+1
        delx_minus(:,k+1) = F_k * delx_plus(:,k) + G_k * [0,0,0,0]';
        P_minus(:,:,k+1) = F_k*P_plus(:,:,k)*F_k' + omega_matrix*Q_filter*omega_matrix';

        %measurement update/correction step for time k+1
        K(:,:,k+1) = P_minus(:,:,k+1) * H_k_plus_1' * ...
            (H_k_plus_1 * P_minus(:,:,k+1) * H_k_plus_1' + Rtrue)^(-1);

        % Calculate the predicted measurements from the Kalman filter prediction
        dely_predict(:,k+1) = H_k_plus_1 * delx_minus(:,k+1);

        % Compute initial difference vector including handling for non-angle components
        dely_diff(:,k+1) = dely(k+1,:)' - dely_predict(:,k+1);

        % Correct angle differences due to wrapping issues
        dely_diff(1,k+1) = wrappedAngleDiff(dely(k+1,1), dely_predict(1,k+1));
        dely_diff(3,k+1) = wrappedAngleDiff(dely(k+1,3), dely_predict(3,k+1));


        % delx_plus(:,k+1) = delx_minus(:,k+1) + K(:,:,k+1) * ...
        %                     (dely(k+1,:)' - H_k_plus_1 * delx_minus(:,k+1) );
        delx_plus(:,k+1) = delx_minus(:,k+1) + K(:,:,k+1) * ...
            (dely_diff(:,k+1));
        P_plus(:,:,k+1) = (eye(6) - K(:,:,k+1) * H_k_plus_1) * P_minus(:,:,k+1);


    end

    total_state = x_nominal + delx_plus';  % Transpose delx_plus to match dimensions of x_nominal

    % Calculate the errors for each state
    state_errors = total_state - x_true;

    squaredErrors = state_errors.^2;      % Square each element of the matrix
    meanSquaredErrors = mean(squaredErrors);  % Compute mean of squared errors for each column
    rmse = sum(sqrt(meanSquaredErrors),'all');
    total_rmse = total_rmse + rmse;
end

total_rmse = total_rmse / 10;  % Average RMSE over all seeds
close(h);  % Close the progress bar
end

