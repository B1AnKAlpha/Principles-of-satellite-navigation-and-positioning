clear;
clc;
close all;

% --- 全局参数和初始化 ---
c = 299792458; % 光速 (m/s)
pos_guess = [0; 0; 0; 0]; % 初始猜测位置 (X,Y,Z) 和接收机钟差
all_pos = []; % 存储所有历元的解算位置
all_clk = []; % 存储所有历元的钟差
MAX_ITER = 15;
CONV_THRESH = 1e-5;
ELEVATION_MASK = 15; % (度)

fprintf('SPP程序开始执行...\n');
fprintf('初始坐标猜测值 (X,Y,Z): %.1f, %.1f, %.1f m\n', pos_guess(1:3));
fprintf('高度角掩码: %d 度\n', ELEVATION_MASK);
fprintf('最大迭代次数: %d, 收敛阈值: %.1e m\n', MAX_ITER, CONV_THRESH);

% --- 步骤1: 加载星历数据(钟差) ---
try
    eph_data = read_rinex_clock_data('c.txt');
    disp('广播星历钟差数据加载成功！(注意: 根据实验要求，解算中未使用卫星钟差改正)');
catch ME
    fprintf(2, '加载 c.txt 文件失败: %s\n', ME.message);
    return;
end

% --- 定义电离层Klobuchar模型参数 ---
iono_params.alpha = [0.1118E-07,  0.1490E-07, -0.5960E-07, -0.1192E-06];
iono_params.beta  = [0.1167E+06,  0.1311E+06, -0.1966E+06, -0.3277E+06];
disp('使用标准Klobuchar参数进行电离层改正。');

% --- 步骤2: 读取观测数据并逐历元处理 ---
file_id = fopen('data.txt', 'r');
if file_id == -1, error('无法打开文件 data.txt。'); end

current_epoch_info = struct('prn', {}, 'data', {});
current_epoch_time = [];
pos_solution = []; % 初始化

is_first_epoch = true;
first_solution_discarded = false; 

while ~feof(file_id)
    line = fgetl(file_id);
    if ~ischar(line) || isempty(strtrim(line)), continue; end
    
    if startsWith(strtrim(line), '>')
        if ~isempty(current_epoch_info)
            disp('----------------------------------------------------');
            fprintf('开始处理历元: %s, 共 %d 颗原始观测卫星.\n', datestr(current_epoch_time), numel(current_epoch_info));
            
            if is_first_epoch
                 pos_guess = [0; 0; 0; 0];
            else
                 pos_guess = pos_solution;
            end
            
            [pos_solution, success] = calculate_spp(current_epoch_info, pos_guess, iono_params, current_epoch_time, c, MAX_ITER, CONV_THRESH, ELEVATION_MASK);
            
            if success
                is_first_epoch = false;
                fprintf('定位成功! 位置 (X,Y,Z): %.3f, %.3f, %.3f, 钟差: %.3f m\n', pos_solution(1), pos_solution(2), pos_solution(3), pos_solution(4));
                
                if ~first_solution_discarded
                    fprintf('注意: 第一个成功解算的历元结果可能因冷启动不准，已自动剔除，不用于最终统计和绘图。\n');
                    first_solution_discarded = true;
                else
                    all_pos = [all_pos, pos_solution(1:3)];
                    all_clk = [all_clk, pos_solution(4)]; % 存储钟差
                end

            else
                disp('该历元定位失败.');
                is_first_epoch = true; 
            end
        end
        
        time_data = sscanf(line, '>%d %d %d %d %d %f');
        current_epoch_time = datetime(time_data(1:6)');
        current_epoch_info = struct('prn', {}, 'data', {});
        disp(line);
        
    else
        prn = sscanf(line, '%s', 1);
        data = sscanf(line(4:end), '%f');
        if numel(data) == 5
            current_epoch_info(end+1).prn = prn;
            current_epoch_info(end).data = data;
        end
    end
end
fclose(file_id);

% --- 结果可视化与输出 (增强版) ---
disp('====================================================');
disp('所有历元处理完毕。');

if ~isempty(all_pos)
    num_epochs = size(all_pos, 2);
    epoch_axis = 1:num_epochs;
    
    % --- 1. 计算平均值和误差序列 ---
    mean_pos = mean(all_pos, 2);
    mean_clk = mean(all_clk);
    
    pos_errors = all_pos - mean_pos; % 计算每个点相对于平均值的偏差
    
    % --- 2. 绘制XYZ分量误差序列图 (核心可视化) ---
    figure('Name', '坐标分量误差序列 (含大气改正)');
    
    % X分量误差
    subplot(3, 1, 1);
    plot(epoch_axis, pos_errors(1,:), 'r-o', 'MarkerSize', 4);
    grid on;
    ylabel('dX (m)');
    title('各坐标分量误差序列 (相对于平均值)');
    
    % Y分量误差
    subplot(3, 1, 2);
    plot(epoch_axis, pos_errors(2,:), 'g-s', 'MarkerSize', 4);
    grid on;
    ylabel('dY (m)');
    
    % Z分量误差
    subplot(3, 1, 3);
    plot(epoch_axis, pos_errors(3,:), 'b-^', 'MarkerSize', 4);
    grid on;
    xlabel('历元序号 (稳定点)');
    ylabel('dZ (m)');
    
    % --- 3. 绘制接收机钟差变化图 ---
    figure('Name', '接收机钟差 (含大气改正)');
    plot(epoch_axis, all_clk, '-s', 'MarkerFaceColor', 'm');
    grid on; xlabel('历元序号 (稳定点)'); ylabel('接收机钟差 (m)');
    title('接收机钟差变化趋势');
    
    % --- 4. 最终结果输出 (增加标准差统计) ---
    pos_std = std(all_pos, 0, 2); % 计算X,Y,Z各方向的标准差
    
    fprintf('\n--- 最终统计结果 (已剔除第一个异常点) ---\n');
    fprintf('时段内平均接收机位置: %.3f, %.3f, %.3f\n', mean_pos');
    fprintf('时段内平均接收机钟差: %.3f m  (%.3f ns)\n', mean_clk, mean_clk/c*1e9);
    fprintf('定位结果标准差 (X,Y,Z): %.3f, %.3f, %.3f m\n', pos_std(1), pos_std(2), pos_std(3));
    
else
    disp('没有足够的数据进行分析和绘图。');
end


% =========================================================================
%                         函数定义部分 (保持不变)
% =========================================================================

function eph_map = read_rinex_clock_data(filename)
    % (此函数无需修改)
    fid = fopen(filename, 'r');
    if fid == -1, error('无法打开文件: %s', filename); end
    eph_map = containers.Map('KeyType', 'char', 'ValueType', 'any');
    while ~feof(fid)
        line = fgetl(fid);
        if ~ischar(line) || isempty(strtrim(line)), continue; end
        if startsWith(line, 'G')
            if length(line) < 80, continue; end
            eph = struct();
            eph.prn = strtrim(line(1:3));
            time_vec = [str2double(line(5:8)), str2double(line(10:11)), str2double(line(13:14)), ...
                        str2double(line(16:17)), str2double(line(19:20)), str2double(line(22:23))];
            eph.toc = datetime(time_vec);
            eph.af0 = str2double(line(24:42));
            eph.af1 = str2double(line(43:61));
            eph.af2 = str2double(line(62:80));
            eph_map(eph.prn) = eph;
            for i = 1:7, if ~feof(fid), fgetl(fid); end, end
        end
    end
    fclose(fid);
end

function [final_pos, success] = calculate_spp(epoch_info, initial_pos, iono_params, t_rx, c, max_iter, conv_thresh, elevation_mask)
    % (此函数保持不变)
    pos = initial_pos;
    
    is_first_iter_at_origin = (norm(pos(1:3)) < 1.0);
    valid_sat_indices = [];
    if is_first_iter_at_origin
        valid_sat_indices = 1:numel(epoch_info);
    else
        for i = 1:numel(epoch_info)
            sat_pos_ecef_col = epoch_info(i).data(1:3);
            [~, el_deg, ~] = ecef2azel(pos(1:3)', sat_pos_ecef_col'); 
            if el_deg >= elevation_mask
                valid_sat_indices(end+1) = i;
            end
        end
    end
    
    num_valid_sats = numel(valid_sat_indices);
    if num_valid_sats < 4
        fprintf('历元 %s: 可用卫星不足4颗 (%d颗)，无法定位。\n', datestr(t_rx), num_valid_sats);
        final_pos = pos; success = false;
        return;
    end
    
    for iter = 1:max_iter
        
        valid_sat_xyz = [];
        proc_ranges = [];
        
        for i = valid_sat_indices
            sat_pos_ecef_col = epoch_info(i).data(1:3);
            raw_range = epoch_info(i).data(4);
            
            ion_delay = 0;
            trop_delay = 0;
            
            if ~(iter == 1 && is_first_iter_at_origin)
                [lat_u_deg, lon_u_deg, h_u] = ecef2geodetic(pos(1:3)');
                [az_deg, el_deg, ~] = ecef2azel(pos(1:3)', sat_pos_ecef_col');
                gps_seconds_of_day = 3600*hour(t_rx) + 60*minute(t_rx) + second(t_rx);
                ion_delay = klobuchar_model(lat_u_deg, lon_u_deg, el_deg, az_deg, gps_seconds_of_day, iono_params);
                trop_delay = saastamoinen_model(h_u, el_deg);
            end
            
            valid_sat_xyz = [valid_sat_xyz; sat_pos_ecef_col'];
            proc_ranges = [proc_ranges; raw_range - ion_delay - trop_delay];
        end
        
        p0 = sqrt(sum((valid_sat_xyz - pos(1:3)').^2, 2));
        los_vectors = (valid_sat_xyz - pos(1:3)') ./ p0;
        B = [-los_vectors, ones(num_valid_sats, 1)];
        L = proc_ranges - p0 - pos(4);
        
        try
            deltap = pinv(B) * L;
            if any(isnan(deltap)) || any(isinf(deltap))
                fprintf('警告: 解算结果包含 NaN 或 Inf，迭代在第 %d 次失败。\n', iter);
                final_pos = pos; success = false;
                return;
            end
        catch ME
             fprintf('警告: 解算矩阵时发生错误: %s\n', ME.message);
             final_pos = pos; success = false;
             return;
        end
        
        pos = pos + deltap;
        
        try
            Q = inv(B'*B); GDOP = sqrt(trace(Q));
            fprintf('  - Iter %d: |dX|=%.2f m, GDOP=%.2f, Sats=%d\n', iter, norm(deltap(1:3)), GDOP, num_valid_sats);
        catch
            fprintf('  - Iter %d: |dX|=%.2f m, GDOP=inf, Sats=%d\n', iter, norm(deltap(1:3)), num_valid_sats);
        end
        
        if norm(deltap(1:3)) < conv_thresh
            fprintf('在第 %d 次迭代后收敛。\n', iter);
            final_pos = pos; success = true;
            return;
        end
    end
    
    fprintf('警告: 达到最大迭代次数 (%d) 仍未收敛。\n', max_iter);
    final_pos = pos; success = false;
end


function [lat, lon, h] = ecef2geodetic(ecef)
    % (此函数无需修改)
    a = 6378137.0; f = 1/298.257223563; e2 = 2*f - f^2;
    x = ecef(1); y = ecef(2); z = ecef(3);
    p = sqrt(x^2 + y^2); lon = atan2(y, x);
    lat_old = atan2(z, p * (1 - e2)); h_old = 0;
    for i = 1:10
        N = a / sqrt(1 - e2 * sin(lat_old)^2);
        h = p / cos(lat_old) - N;
        lat = atan2(z, p * (1 - e2 * N / (N + h)));
        if abs(lat - lat_old) < 1e-12 && abs(h - h_old) < 1e-12, break; end
        lat_old = lat; h_old = h;
    end
    lat = rad2deg(lat); lon = rad2deg(lon);
end

function [az, el, dist] = ecef2azel(user_pos, sat_pos)
    % (此函数无需修改)
    [lat, lon, ~] = ecef2geodetic(user_pos);
    lat = deg2rad(lat); lon = deg2rad(lon);
    R = [-sin(lon),cos(lon),0; -sin(lat)*cos(lon),-sin(lat)*sin(lon),cos(lat); cos(lat)*cos(lon),cos(lat)*sin(lon),sin(lat)];
    d_ecef = (sat_pos - user_pos)'; 
    d_enu = R * d_ecef;
    E = d_enu(1); N = d_enu(2); U = d_enu(3);
    dist = norm(d_enu); el = rad2deg(atan2(U, sqrt(E^2 + N^2)));
    az = rad2deg(atan2(E, N)); if az < 0, az = az + 360; end
end

function ion_delay = klobuchar_model(user_lat_deg, user_lon_deg, sat_el_deg, sat_az_deg, t_gps, iono)
    % (此函数无需修改)
    c = 299792458;
    el_sc = sat_el_deg / 180;
    lat_u_sc = user_lat_deg / 180;
    lon_u_sc = user_lon_deg / 180;
    az_rad = deg2rad(sat_az_deg);
    psi = 0.0137 / (el_sc + 0.11) - 0.022;
    lat_ipp_sc = lat_u_sc + psi * cos(az_rad);
    if lat_ipp_sc > 0.416, lat_ipp_sc = 0.416; elseif lat_ipp_sc < -0.416, lat_ipp_sc = -0.416; end
    lon_ipp_sc = lon_u_sc + (psi * sin(az_rad)) / cos(lat_ipp_sc * pi);
    lat_m_sc = lat_ipp_sc + 0.064 * cos((lon_ipp_sc - 1.617) * pi);
    t_local = 4.32e4 * lon_ipp_sc + t_gps;
    t_local = mod(t_local, 86400);
    if t_local >= 86400, t_local = t_local - 86400; end
    if t_local < 0, t_local = t_local + 86400; end
    AMP = iono.alpha(1) + iono.alpha(2)*lat_m_sc + iono.alpha(3)*lat_m_sc^2 + iono.alpha(4)*lat_m_sc^3;
    if AMP < 0, AMP = 0; end
    PER = iono.beta(1) + iono.beta(2)*lat_m_sc + iono.beta(3)*lat_m_sc^2 + iono.beta(4)*lat_m_sc^3;
    if PER < 72000, PER = 72000; end
    x = 2 * pi * (t_local - 50400) / PER;
    F = 1.0 + 16.0 * (0.53 - el_sc)^3;
    if abs(x) < 1.57
        ion_delay = c * F * (5e-9 + AMP * (1 - x^2/2 + x^4/24));
    else
        ion_delay = c * F * 5e-9;
    end
end

function trop_delay = saastamoinen_model(h, el)
    % (此函数无需修改)
    if h < -1000 || h > 10000, h = 0; end
    P0 = 1013.25; T0 = 288.15; H0 = 0.50;
    P = P0 * (1 - 2.26e-5 * h)^5.225;
    T = T0 - 6.5e-3 * h;
    e = H0 * exp(-37.2465 + 0.213166*T - 0.000256908*T^2);
    zd = 0.002277 * P + (0.002277 * (0.05 + 1255/T) * e);
    el_rad = deg2rad(el);
    if el_rad <= 0, el_rad = 1e-6; end
    trop_delay = zd / sin(el_rad);
end