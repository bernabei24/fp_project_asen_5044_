clear;
clc;
close all;

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

%constructing initial vectors
perturb_x0 = [0; 1; 0; 0; 0; 0.1];
x_init = [Eg_init Ng_init thetag_init Ea_init Na_init thetaa_init]';
u_init = [vg_init phi_init va_init omegaa_init]';

%Define A(x,u)
A_func = @(x,u) [0 0 -u(1,1)*sin(x(3,1)) 0 0 0; %not necessary for ODE45, but may be helpful for linearization
             0 0  u(1,1)*cos(x(3,1)) 0 0 0;
             0 0  0                  0 0 0;
             0 0 0 0 0  u(3,1)*sin(x(6,1));
             0 0 0 0 0 -u(3,1)*cos(x(6,1));
             0 0 0 0 0 0];

%Define B(x,u)
B_func = @(x,u) [cos(x(3,1)) 0 0 0; %not necessary for ODE45, but may be helpful for linearization
             sin(x(3,1)) 0 0 0;
             tan(u(2,1))/L (u(1,1)/L)*( sec(u(2,1))^2 ) 0 0;
             0 0 cos(x(6,1)) 0;
             0 0 sin(x(6,1)) 0;
             0 0 0 1];
%Define input
u_func = @(t, x) u_init; % Constant control input

%Timespan for simulation
t_span = 0:0.1:100; % Time from 0 to 100 seconds in 0.1-second steps

% Define the nonlinear dynamics
dynamics = @(t, x) x_dotODE45(t, x, u_func,L);

% Solve using ode45
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%PERTURBATION ADDED
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[t, x] = ode45(dynamics, t_span, x_init + perturb_x0); %perturbation added
%[t, x] = ode45(dynamics, t_span, x_init); %use if perturbation unwanted

% Wrap the angles theta_g (x(3,:)) and theta_a (x(6,:)) to [-pi, pi]
x(:, 3) = mod(x(:, 3) + pi, 2*pi) - pi;  % Wrap theta_g (ground heading)
x(:, 6) = mod(x(:, 6) + pi, 2*pi) - pi;  % Wrap theta_a (air heading)

% Plot results
figure;
for i = 1:size(x, 2)
    subplot(size(x, 2), 1, i);
    plot(t, x(:, i), 'LineWidth', 1.5);
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
end
sgtitle('State Trajectories over Time With Perturbation', 'Interpreter', 'latex');










