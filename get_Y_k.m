function Y_k = get_Y_k(x_k)
% inputs
    % x_k: 6-element state vector at time k
% outputs
    % Y_k: 5-element sensr values at time k

    % could try wrapping x_k(3) and x_k(6)
    % wrap x_k(3) and x_k(6) so predicted measurements don't go out of bounds
    %x_k(3) = mod(x_k(3) + pi, 2*pi) - pi;
    %x_k(6) = mod(x_k(6) + pi, 2*pi) - pi;

    Y_k = [atan2((x_k(5) - x_k(2)), (x_k(4) - x_k(1))) - x_k(3);
           sqrt((x_k(1) - x_k(4))^2 + (x_k(2) - x_k(5))^2);
           atan2((x_k(2) - x_k(5)), (x_k(1) - x_k(4))) - x_k(6);
           x_k(4);
           x_k(5)];
end

