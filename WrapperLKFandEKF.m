clear;
clc;
close all;

load("cooplocalization_finalproj_KFdata.mat")

%initial conditions

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

%GENERATE RANDOM PROCESS NOISE VECTORS
% Check if all eigenvalues of Q are positive
eigenvaluesQ = eig(Qtrue);
rng(15); % for reproduceability
if all(eigenvaluesQ > 0)
    disp('The matrix Q is positive definite.');

    % Perform the Cholesky decomposition
    LowerQ = chol(Qtrue, 'lower');

    % Generate a matrix of standard normal random variables
    
    ZQ = randn(6, 1001);

    % Multiply by the Cholesky factor to get the random vectors with covariance Q
    w_k = LowerQ * ZQ;

else
    disp('The matrix Q is not positive definite.');
end

%GENERATE RANDOM MEASUREMENT NOISE VECTORS
eigenvaluesR = eig(Rtrue);
if all(eigenvaluesR > 0)
    disp('The matrix R is positive definite.');

    % Perform the Cholesky decomposition
    LowerR = chol(Rtrue, 'lower');

    % Generate a matrix of standard normal random variables
    
    ZR = randn(5, 1001);

    % Multiply by the Cholesky factor to get the random vectors with covariance Q
    v_k = LowerR * ZR;

else
    disp('The matrix R is not positive definite.');
end

%constructing initial vectors
perturb_x0 = [0; 1; 0; 0; 0; 0.1];
x_init = [Eg_init Ng_init thetag_init Ea_init Na_init thetaa_init]';
u_init = [vg_init phi_init va_init omegaa_init]';

%Define input
u_func = @(t, x) u_init; % Constant control input
w_func = @(t) w_k(:, floor(t / 0.1) + 1);

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

figure;
for i = 1:size(x_true, 2)
    subplot(size(x_true, 2), 1, i);
    
    % Plot x_true in red
    plot(t, x_true(:, i), 'r', 'LineWidth', 1.5); % 'r' specifies red color
    hold on;  % Keep the plot to overlay the next data set
    
    % Plot x_nominal in blue
    plot(t, x_nominal(:, i), 'b', 'LineWidth', 1.5); % 'b' specifies blue color
    
    grid on;
    
    % Adjust titles and labels based on the state variables
    if i == 1
        title('$\xi$ (Easting of ground)', 'Interpreter', 'latex');
        ylabel('$\xi$ (m)', 'Interpreter', 'latex');
    elseif i == 2
        title('$\eta$ (Northing of ground)', 'Interpreter', 'latex');
        ylabel('$\eta$ (m)', 'Interpreter', 'latex');
    elseif i == 3
        title('$\theta$ (Heading of ground)', 'Interpreter', 'latex');
        ylabel('$\theta$ (rad)', 'Interpreter', 'latex');
    elseif i == 4
        title('$\xi$ (Easting of air)', 'Interpreter', 'latex');
        ylabel('$\xi$ (m)', 'Interpreter', 'latex');
    elseif i == 5
        title('$\eta$ (Northing of air)', 'Interpreter', 'latex');
        ylabel('$\eta$ (m)', 'Interpreter', 'latex');
    elseif i == 6
        title('$\theta$ (Heading of air)', 'Interpreter', 'latex');
        ylabel('$\theta$ (rad)', 'Interpreter', 'latex');
    end
    
    xlabel('Time (s)', 'Interpreter', 'latex');
    
    % Add legend to clarify the plots
    if i == 1  % Add legend only in the first subplot to avoid repetition
        legend({'True State', 'Nominal State'}, 'Interpreter', 'latex');
    end
    
    hold off;  % Release the plot for next subplot operations
end

% Supertitle for all subplots
sgtitle('True State vs Nominal State Trajectories Comparison', 'Interpreter', 'latex');

% find total measurement vector
y_true = get_Y_noise(x_true,v_k');
y_nom = get_Y(x_nominal);

% Assuming y_true and y_nom are your matrices, each of size 1001x5
y_true(:, 1) = wrapToPi(y_true(:, 1));  % Wrap the first column (angles) of y_true
y_true(:, 3) = wrapToPi(y_true(:, 3));  % Wrap the third column (angles) of y_true

y_nom(:, 1) = wrapToPi(y_nom(:, 1));    % Wrap the first column (angles) of y_nom
y_nom(:, 3) = wrapToPi(y_nom(:, 3));    % Wrap the third column (angles) of y_nom

% Plot Truth Model Measurements
figure;
for i = 1:size(y_true, 2)
    subplot(size(y_true, 2), 1, i);
    plot(t, y_true(:, i), 'LineWidth', 1.5);
    hold on; % Keep the current plot
    plot(t, y_nom(:, i), 'r', 'LineWidth', 1.5); % Red line for nominal data
    hold off; % Release the plot for new settings
    grid on;
    
    legend('True State', 'Nominal State', 'Location', 'best');

    % Adjust titles and labels based on the state variables
    if i == 1
        title('$\gamma_{ag}$ (Bearing UAV to UGV)', 'Interpreter', 'latex');
        ylabel('$\gamma_{ag}$ (rad)', 'Interpreter', 'latex');
    elseif i == 2
        title('$\rho_{ga}$ (Distance UGV to UAV)', 'Interpreter', 'latex');
        ylabel('$\rho_{ga}$ (m)', 'Interpreter', 'latex');
    elseif i == 3
        title('$\gamma_{ga}$ (Bearing UGV to UAV)', 'Interpreter', 'latex');
        ylabel('$\gamma_{ga}$ (rad)', 'Interpreter', 'latex');
    elseif i == 4
        title('$\xi_{a}$ (Easting of UAV)', 'Interpreter', 'latex');
        ylabel('$\xi_{a}$ (m)', 'Interpreter', 'latex');
    elseif i == 5
        title('$\eta_{a}$ (Northing of UAV)', 'Interpreter', 'latex');
        ylabel('$\eta_{a}$ (m)', 'Interpreter', 'latex');
    end
    xlabel('Time (s)', 'Interpreter', 'latex');
end
sgtitle('Truth Measurments vs. Time', 'Interpreter', 'latex');

%INITIALIZING FOR LKF LOOP
%pretty sure this is what gamme looks like although not positive
gamma = eye(size(x_true,2));
omega_matrix = dt * gamma;

%for testing on real data else, comment out
% y_true(2:end,:) = ydata(:,2:end)';
% y_true(1,:) = y_nom(1,:);

dely = y_true - y_nom;


delx_plus = zeros(6,1001);
delx_minus = zeros(6,1001);
P_plus = zeros(6,6,1001);
P_minus = zeros(6,6,1001);
K = zeros(6,5,1001);

[del_x_0,P_plus_0] = get_init_conditions(dely,x_nominal,u_init,dt,Rtrue,10)

delx_plus(:,1) = del_x_0; %adjustable
P_plus(:,:,1) = P_plus_0; %adjustable
dely_diff = zeros(5,1001);
dely_predict = zeros(5,1001);

Q_filter = 1 * Qtrue;

timestep_switch = 300;

x_plus = zeros(6,1001);
x_min = zeros(6,1001);
e_y = zeros(5,1001);
y_min = zeros(5,1001);

% set up CT nonlinear dynamics functions
f = @(t, x) x_dotODE45(t, x, u_func, L); % for computing trajectory online

%Compute jacobians at each time step from nominal trajectory
for k = 1:1000 %k=1 represents t = 0
    
    if k < timestep_switch
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
    else
        if k == timestep_switch
            x_plus(:,1:timestep_switch) = x_nominal(1:timestep_switch,:)' + delx_plus(:,1:timestep_switch);
            y_min(:,1:timestep_switch) = y_nom(1:timestep_switch,:)' + dely_predict(:,1:timestep_switch);
            e_y(:,1:timestep_switch) = dely_diff(:,1:timestep_switch);
        end
        % step 3: time update/prediction step for time k + 1
        x_plus_k = x_plus(:, k);
        [t, x_min_kplus1] = ode45(f, tvec(k:k+1), x_plus_k);
        x_min(:, k + 1) = x_min_kplus1(end, :)';
        A = get_Abar(u_init, x_plus(:, k));
        F_k = eye(6) + dt * A;
        P_minus(:, :, k + 1) = F_k * P_plus(:, :, k) * F_k' + omega_matrix * Q_filter * omega_matrix';
        
        % step 4: measurement update/correction step for k + 1
        y_min(:,k+1) = get_Y_k(x_min(:, k + 1));
        H = get_Cbar(x_min(:, k + 1));

        y_min(1, k+1) = wrapToPi(y_min(1, k+1));  % Wrap the 1st row, k+1 column
        y_min(3, k+1) = wrapToPi(y_min(3, k+1));  % Wrap the 3rd row, k+1 column
        
        e_y(:,k+1) = ydata(:, k + 1) - y_min(:,k+1);

        e_y(1, k+1) = wrappedAngleDiff(ydata(1, k+1), y_min(1, k+1));
        e_y(3, k+1) = wrappedAngleDiff(ydata(3, k+1), y_min(3, k+1));

        K = P_minus(:, :, k+1) * H' / (H * P_minus(:, :, k+1) * H' + Rtrue);

        x_plus(:, k + 1) = x_min(:, k + 1) + K * e_y(:,k+1);
        P_plus(:, :, k + 1) = (eye(6) - K * H) * P_minus(:, :, k+1);

    end

end

x_plus = x_plus';
t = dt*(0:1000);

% plot estimated state results
% Wrap the angles theta_g (x_total(3,:)) and theta_a (x_total(6,:)) to [-pi, pi]
x_plus(:, 3) = mod(x_plus(:, 3) + pi, 2*pi) - pi;  % Wrap theta_g (ground heading)
x_plus(:, 6) = mod(x_plus(:, 6) + pi, 2*pi) - pi;  % Wrap theta_a (air heading)
x_true(:, 3) = mod(x_true(:, 3) + pi, 2*pi) - pi;  % Wrap theta_g (ground heading)
x_true(:, 6) = mod(x_true(:, 6) + pi, 2*pi) - pi;  % Wrap theta_a (air heading)


plotInnovationsAndMeasurements(e_y, y_true, y_min);

plot_states_and_errorsEKF(x_plus,x_true,P_plus,tvec)
