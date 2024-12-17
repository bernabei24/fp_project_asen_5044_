function [delx_0, P_0] = warm_start(dely, x_nom, delu, L, R)

    dt = 0.1;

    dely = dely(:, 1:10);
    dely = reshape(dely, [50, 1]);
    R = blkdiag(R, R, R, R, R, R, R, R, R, R);

    % first row
    H_0 = get_Cbar(x_nom(1, :)');
    STM = H_0;

    % second row
    H_1 = get_Cbar(x_nom(2, :)');

    A_nom_0 = get_Abar(delu, x_nom(1, :)');
    F_0 = eye(6) + dt * A_nom_0;

    B_nom_0 = get_Bbar(delu, x_nom(1, :)', L);
    G_0 = dt * B_nom_0;

    F_block = F_0 + G_0 * delu;

    STM = [STM; H_1 * F_block];

    for k = 3:10
        C_nom_k = get_Cbar(x_nom(k, :)');
        H_k = C_nom_k;

        A_nom_kmin1 = get_Abar(delu, x_nom(k - 1, :)');
        F_kmin1 = eye(6) + dt * A_nom_kmin1;

        F_block = F_kmin1 * F_block;

        STM = [STM; H_k * F_block];
    end

    P_0 = (STM' * R^(-1) * STM)^(-1)
    delx_0 = STM\dely

end

