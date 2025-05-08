clear all; close all; clc;

BG = imread('21897_0.jpg');   % 讀取車輛圖片檔案
BGgray = double(rgb2gray(BG));  % 轉灰階並轉為 double
[row, col] = size(BGgray);      % 圖片尺寸
BlockSize = 12;                 % 區塊大小（可自由修改）

average = zeros(row, col);      % 用來儲存每個像素所在區塊的平均值

for i = 1:BlockSize:row
    for j = 1:BlockSize:col
        % 計算區塊實際範圍，避免超出邊界
        row_end = min(i + BlockSize - 1, row);
        col_end = min(j + BlockSize - 1, col);
        
        block = BGgray(i:row_end, j:col_end);
        blockMean = mean(block(:));
        
        average(i:row_end, j:col_end) = blockMean;
    end
end

%figure; imshow(uint8(average)); title('局部平均圖');

% 二值化處理（使用平均值 - offset 當作門檻）
BinInmg = zeros(row, col);
offset = 10;  % 可以調整這個值以提高或降低靈敏度
BinInmg(BGgray > average - offset) = 255;

figure; imshow(uint8(BinInmg)); title('局部平均二值化');


% STEP 1：中值濾波去除雜訊
% -----------------------------------------------
% 使用 3x3 中值濾波去除單點雜訊，保留主要形狀
BinInmg_filtered = medfilt2(uint8(BinInmg), [5 5]);
figure;
imshow(BinInmg_filtered);
title('中值濾波偵測結果');
% STEP 2：Sobel 邊緣偵測
% -----------------------------------------------
% 對降噪後的二值圖進行邊緣偵測（偵測灰階梯度變化處）
edges = edge(BinInmg_filtered, 'Sobel');
figure;
imshow(edges);
title('Sobel偵測結果');
% STEP 3：移除小區塊雜訊
% -----------------------------------------------
% 移除小於 30 像素的連通區域（避免破碎雜訊干擾後續分析）
edges_clean = bwareaopen(edges, 60);

% STEP 4：顯示處理後的邊緣結果
% -----------------------------------------------
figure;
imshow(edges_clean);
title('經過平滑與去雜訊的邊緣偵測結果');


% --- 邊緣處理完後進行形態學補強與偵測區塊 ---
se = strel('rectangle', [1 25]);           % 橫向拉長以連接文字邊緣
morphed = imclose(edges_clean, se);              % 閉運算連接破碎邊緣（先膨脹後侵蝕）

stats = regionprops(morphed, 'BoundingBox');  % 抓出所有連通區域的邊界框

imgHeight = row;
imgWidth = col;

bestScore = 0;
bestBox = [];

targetAspect = 3.5;  % 預期車牌的長寬比
minArea = (imgHeight * imgWidth) * 0.001;
maxArea = (imgHeight * imgWidth) * 0.05;

for k = 1:length(stats)
    bbox = stats(k).BoundingBox;
    w = bbox(3); h = bbox(4);
    area = w * h;
    aspect = w / h;

    % 條件：不再限制位置，只看面積與長寬比
    if aspect > 2 && aspect < 6 && ...
       area > minArea && area < maxArea

        % 邊緣密度計算
        edgeCrop = imcrop(edges_clean, bbox);
        normDensity = sum(edgeCrop(:)) / numel(edgeCrop);

        % 長寬比相似度計算（越接近 targetAspect 越好）
        aspectScore = 1 - abs(aspect - targetAspect) / targetAspect;

        % 綜合評分（你可以調整權重）
        score = 0.4 * normDensity + 0.6 * aspectScore;
        
        % 畫出此候選框（藍色）
        rectangle('Position', bbox, 'EdgeColor', 'b', 'LineWidth', 1);

        if score > bestScore
            bestScore = score;
            bestBox = bbox;
        end
    end
end

% 顯示最佳車牌候選框（綠色）
if ~isempty(bestBox)
    rectangle('Position', bestBox, 'EdgeColor', 'g', 'LineWidth', 2);
    title('綠色：最佳車牌候選框，藍色：其他候選區塊', 'FontSize', 14, 'Color', 'g');
else
    title('未偵測到車牌', 'FontSize', 14, 'Color', 'r');
end

hold off;
