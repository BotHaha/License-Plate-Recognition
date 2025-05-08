clear all; close all; clc;

BG = imread('21889_0.jpg');   % 讀取車輛圖片檔案
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
offset = 12;  % 可以調整這個值以提高或降低靈敏度
BinInmg(BGgray > average - offset) = 255;

%figure; imshow(uint8(BinInmg)); title('局部平均二值化');


% STEP 1：中值濾波去除雜訊
% -----------------------------------------------
% 使用 3x3 中值濾波去除單點雜訊，保留主要形狀
BinInmg_filtered = medfilt2(uint8(BinInmg), [9 9]);
figure;
imshow(BinInmg_filtered);
title('中值濾波偵測結果');
% STEP 2：形態學梯度（Morphological Gradient）邊緣偵測
se = strel('square', 5);  % 可調整為 [3 3] 或 [5 5] 觀察結果差異
dilated = imdilate(BinInmg_filtered, se);
eroded  = imerode(BinInmg_filtered, se);
edges = dilated - eroded;

figure;
imshow(edges);
title('Morphological Gradient 邊緣偵測結果');
% STEP 3：移除小區塊雜訊
% -----------------------------------------------
% 移除小於 30 像素的連通區域（避免破碎雜訊干擾後續分析）
edges_clean = bwareaopen(edges, 90);

% STEP 4：顯示處理後的邊緣結果
% -----------------------------------------------
figure;
imshow(edges_clean);
title('經過平滑與去雜訊的邊緣偵測結果');


% --- 邊緣處理完後進行形態學補強與偵測區塊 ---
se_final = strel('rectangle', [1 25]);           % 橫向拉長以連接文字邊緣
morphed = imclose(edges_clean, se_final);              % 閉運算連接破碎邊緣（先膨脹後侵蝕）

stats = regionprops(morphed, 'BoundingBox');  % 抓出所有連通區域的邊界框

% 動態條件
imgHeight = row;
imgWidth = col;
targetAspect = 3.5;
minArea = (imgHeight * imgWidth) * 0.001;
maxArea = (imgHeight * imgWidth) * 0.05;

% 初始化變數
bestOCRBox = [];
bestText = '';
maxConfidence = 0;

figure; imshow(uint8(BGgray)); hold on;

%掃描所有區塊，畫藍框 + OCR 辨識
for k = 1:length(stats)
    bbox = stats(k).BoundingBox;
    w = bbox(3); h = bbox(4);
    area = w * h;
    aspect = w / h;

    if aspect > 1.5 && aspect < 7 && area > minArea * 0.8 && area < maxArea * 1.2
        rectangle('Position', bbox, 'EdgeColor', 'b', 'LineWidth', 1);  % 畫藍框

        % --------- OCR 判斷（替換原來那幾行） ---------
        cropGray = imcrop(uint8(BGgray), bbox);      % 用灰階
        cropAdj  = imadjust(cropGray);              % 對比增強
        cropBig  = imresize(cropAdj,3.5, 'bilinear'); % 放大兩倍
        
        %反相再二值化
        cropBig = imbinarize(imcomplement(cropBig),'adaptive');
        
        result = ocr(cropBig , ...
            'CharacterSet','ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-', ...
            'TextLayout','Word');
        
        text = regexprep(result.Text,'[^A-Z0-9-]','');
        conf = mean(result.CharacterConfidences(~isnan(result.CharacterConfidences)));
        
        fprintf('候選 %d: [%s] conf=%.2f\n', k, text, conf);
        
        % 只要 conf 有數值就更新；即使低也保底有一框
        if isempty(conf); conf = 0; end
        if conf >= maxConfidence
            maxConfidence = conf;
            bestText      = text;
            bestOCRBox    = bbox;
        end
        % ---------------------------------------------
    end
end

% 畫出最佳車牌區塊
if ~isempty(bestOCRBox)
    rectangle('Position', bestOCRBox, 'EdgeColor', 'g', 'LineWidth', 2);
    text(bestOCRBox(1), bestOCRBox(2)-10, ['OCR結果: ', bestText], ...
        'Color','g','FontSize',14,'FontWeight','bold');
    title('OCR 找到信心最高的區塊', 'FontSize', 14, 'Color', 'g');
else
    title('未辨識到文字', 'FontSize', 14, 'Color', 'r');
end

hold off;
