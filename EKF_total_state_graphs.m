function EKF_total_state_graphs(x_truth, x_plus, P_plus, tvec)
    % Validate input dimensions
    if size(x_plus, 2) ~= length(tvec) || size(x_truth, 1) ~= length(tvec)
        error('The number of columns in delx_plus and rows in x_nominal must match the length of tvec.');
    end
    
    % Prepare figure
    figure;
    
    % Number of states
    num_states = size(x_truth, 2);  % Assuming x_nominal is 1001x6
    
    % Compute total state estimates
    total_state_est = x_plus;  % Transpose x_nominal to align and add to delx_plus
    
    % Plot each state with its error bounds
    for i = 1:num_states
        subplot(num_states, 1, i);
        
        % Extract the total state estimate and its standard deviation
        state_est = total_state_est(i, :); % Directly use as a row vector
        state_std = sqrt(squeeze(P_plus(i, i, :)))'; % Standard deviations from diagonal of P_plus
        
        % Time to plot
        time = tvec;
        
        % Plot the state estimate
        plot(time, state_est, time, x_truth(:, i), 'LineWidth', 1.5);
        hold on;
        
        % Plot the error bounds at +-2 standard deviations
        fill([time, fliplr(time)], [state_est + 2 * state_std, fliplr(state_est - 2 * state_std)], ...
            'r', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
        
        % Labels and titles
        title(sprintf('Total State %d', i));
        ylabel(sprintf('State %d', i));
        xlabel('Time (s)');
        legend('Estimate', 'Ground Truth')
        
        % Grid and formatting
        grid on;
        hold off;
    end
    
    % Super title for the figure
    sgtitle('EKF Estimated States vs. Time');
end
