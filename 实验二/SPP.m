clear;
clc;
close all;

% --- 全局参数和初始化 ---
c = 299792458; % 光速 (m/s)
pos_guess = [0; 0; 0; 0]; % 初始猜测位置 [x; y; z; c*dt_r]

all_pos = []; % 存储所有历元的解算位置
all_clk = []; % 存储所有历元的钟差

MAX_ITER = 15;
CONV_THRESH = 1e-5;

% --- 步骤1: 读取并解析广播星历(钟差)文件 ---
% (此部分保持不变)
try
    eph_data = read_rinex_clock_data('c.txt');
    disp('广播星历钟差数据加载成功！(注意：根据实验要求，本次解算未使用此数据)');
catch ME
    fprintf(2, '加载 c.txt 文件失败: %s\n', ME.message);
    return;
end

% --- 步骤2: 读取观测数据并逐历元处理 ---
% (此部分保持不变)
file_id = fopen('data.txt', 'r');
if file_id == -1
    error('无法打开文件 data.txt。');
end

current_epoch_info = struct('prn', {}, 'data', {});
current_epoch_time = [];
pos_solution = []; % 初始化以备后用

while ~feof(file_id)
    line = fgetl(file_id);
    if ~ischar(line) || isempty(strtrim(line)), continue; end
    
    if startsWith(strtrim(line), '>')
        if ~isempty(current_epoch_info)
            disp('----------------------------------------------------');
            fprintf('开始处理历元: %s, 共 %d 颗卫星.\n', datestr(current_epoch_time), numel(current_epoch_info));
            
            [pos_solution, success] = calculate_spp(current_epoch_info, pos_guess, c, MAX_ITER, CONV_THRESH);
            
            if success
                all_pos = [all_pos, pos_solution(1:3)];
                all_clk = [all_clk, pos_solution(4)];
                pos_guess = pos_solution;
                fprintf('定位成功! 位置 (X,Y,Z): %.3f, %.3f, %.3f, 接收机钟差: %.3f m\n', pos_solution(1), pos_solution(2), pos_solution(3), pos_solution(4));
            else
                disp('该历元定位失败.');
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

% (处理最后一个历元部分保持不变)
if ~isempty(current_epoch_info)
    disp('----------------------------------------------------');
    fprintf('开始处理最后一个历元: %s, 共 %d 颗卫星.\n', datestr(current_epoch_time), numel(current_epoch_info));
    [pos_solution, success] = calculate_spp(current_epoch_info, pos_guess, c, MAX_ITER, CONV_THRESH);
    if success
        all_pos = [all_pos, pos_solution(1:3)];
        all_clk = [all_clk, pos_solution(4)];
        fprintf('定位成功! 最终位置 (X,Y,Z): %.3f, %.3f, %.3f, 接收机钟差: %.3f m\n', pos_solution(1), pos_solution(2), pos_solution(3), pos_solution(4));
    else
        disp('该历元定位失败.');
    end
end

fclose(file_id);


% --- 结果可视化与输出 (增强版) ---
if ~isempty(all_pos)
    num_epochs = size(all_pos, 2);
    epoch_axis = 1:num_epochs;
    
    % --- 1. 计算平均值和误差序列 ---
    mean_pos = mean(all_pos, 2);
    mean_clk = mean(all_clk);
    
    pos_errors = all_pos - mean_pos; % 计算每个点相对于平均值的偏差
    
    % --- 2. 绘制三维轨迹图 (可选，但可以保留) ---
    figure;
    plot3(all_pos(1,:), all_pos(2,:), all_pos(3,:), '-o', 'MarkerFaceColor', 'b');
    hold on;
    plot3(mean_pos(1), mean_pos(2), mean_pos(3), 'r*', 'MarkerSize', 10, 'LineWidth', 2);
    grid on; xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');
    title('接收机位置解算轨迹');
    legend('解算点', '平均位置');
    axis equal;
    
    % --- 3. 绘制XYZ分量误差序列图 (核心修改) ---
    figure;
    
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
    xlabel('历元序号');
    ylabel('dZ (m)');
    
    % --- 4. 绘制接收机钟差变化图 (保留) ---
    figure;
    plot(epoch_axis, all_clk, '-s', 'MarkerFaceColor', 'm');
    grid on; xlabel('历元序号'); ylabel('接收机钟差 (m)');
    title('接收机钟差变化趋势');
    
    % --- 5. 最终结果输出 (增加标准差统计) ---
    pos_std = std(all_pos, 0, 2); % 计算X,Y,Z各方向的标准差
    
    disp('====================================================');
    if ~isempty(pos_solution)
        fprintf('最终接收机位置 (最后一个历元): %.3f, %.3f, %.3f\n', pos_solution(1:3)');
        fprintf('最终接收机钟差 (最后一个历元): %.3f m  (%.3f ns)\n', pos_solution(4), pos_solution(4)/c*1e9);
    end
    fprintf('时段内平均接收机位置: %.3f, %.3f, %.3f\n', mean_pos');
    fprintf('时段内平均接收机钟差: %.3f m  (%.3f ns)\n', mean_clk, mean_clk/c*1e9);
    fprintf('定位结果标准差 (X,Y,Z): %.3f, %.3f, %.3f m\n', pos_std(1), pos_std(2), pos_std(3));
    
else
    disp('没有成功解算的历元。');
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
            if length(line) < 80
                warning('卫星 %s 的星历行太短，跳过。', strtrim(line(1:3)));
                 for i = 1:7, if ~feof(fid), fgetl(fid); end, end
                continue;
            end
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

function [final_pos, success] = calculate_spp(epoch_info, initial_pos, c, max_iter, conv_thresh)
    % (此函数保持不变)
    num_sats = numel(epoch_info);
    if num_sats < 4
        disp('卫星数量不足 (<4)，无法定位。');
        final_pos = initial_pos; success = false;
        return;
    end
    
    sat_xyz = zeros(num_sats, 3);
    pseudo_ranges = zeros(num_sats, 1); 
    
    for i = 1:num_sats
        raw_data = epoch_info(i).data;
        sat_xyz(i, :) = raw_data(1:3);
        pseudo_ranges(i) = raw_data(4); 
    end

    pos = initial_pos;
    for iter = 1:max_iter
        p0 = sqrt(sum((sat_xyz - pos(1:3)').^2, 2));
        los_vectors = (sat_xyz - pos(1:3)') ./ p0;
        B = [-los_vectors, ones(num_sats, 1)];
        L = pseudo_ranges - p0 - pos(4); 
        deltap = (B' * B) \ (B' * L);
        pos = pos + deltap;
        if norm(deltap(1:3)) < conv_thresh
            fprintf('在第 %d 次迭代后收敛。\n', iter);
            final_pos = pos; success = true;
            return;
        end
    end
    
    fprintf('警告: 达到最大迭代次数 (%d) 仍未收敛。\n', max_iter);
    final_pos = pos; success = false;
end