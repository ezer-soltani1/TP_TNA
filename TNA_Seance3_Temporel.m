%% TNA - Seance 3
% Analyse -> Gain -> Synthèse

clear; close all; clc;

%% Chargement
fprintf('--- Chargement Données (Temporel) ---\n');
filename = 'pcm_48k.mat';
if exist(filename, 'file')
    data = load(filename);
    vars = fieldnames(data);
    signal = double(data.(vars{1}));
    if size(signal,2) > 1, signal = mean(signal,2); end 
    signal = signal / max(abs(signal));
end
if ~exist('Fs', 'var'), Fs = 48000; end

%% 2. Paramétrage
% Gains pour 5 bandes (x0=Graves ... x4=Aigus)
% Contrainte Prof : Gain entre [0, 1] (Uniquement atténuation pour éviter saturation)
% Profil choisi : Passe-bas progressif
gains_lin = [1, 1, 1, 1, 1]; 
gains_dB = 20*log10(gains_lin + eps);

% Filtres d'Analyse et de Synthèse (Half-band)

N_taps = 64; 
b_low  = fir1(N_taps, 0.5);          % Passe-bas
b_high = fir1(N_taps, 0.5, 'high');  % Passe-haut

%% 3. ANALYSE (Décomposition & Décimation)
fprintf('--> Décomposition...\n');

% Stockage des sous-bandes
% Niveau 1 : x4 (Haut) + Reste (Bas)
% Niveau 2 : x3 (Haut du Reste) + Reste (Bas du Reste) ...
subbands = cell(5, 1);
current_sig = signal;

for i = 4:-1:1 
    % A. Filtrage
    sig_L = filter(b_low, 1, current_sig);
    sig_H = filter(b_high, 1, current_sig);
    
    % B. Décimation (Downsampling par 2)
    sig_L_down = sig_L(1:2:end);
    sig_H_down = sig_H(1:2:end);
    
    % Stockage de la bande haute (x_i)
    subbands{i+1} = sig_H_down;
    
    % On continue le traitement sur la partie basse
    current_sig = sig_L_down;
end
% Le reste final est la bande x0 (Graves profonds)
subbands{1} = current_sig;

%% TRAITEMENT (Gains & VU-mètre)
vu_levels = zeros(5,1);

for k = 1:5
    % Calcul VU-Mètre (RMS) AVANT gain pour voir le signal
    vu_levels(k) = rms(subbands{k});
    
    % Application du Gain
    subbands{k} = subbands{k} * gains_lin(k);
end

%% SYNTHESE (Reconstruction & Interpolation)
fprintf('--> Reconstruction...\n');
reconstructed = subbands{1};

for i = 1:4
    sig_L_in = reconstructed;
    sig_H_in = subbands{i+1};
    len_target = max(length(sig_L_in), length(sig_H_in)) * 2;
    
    % Upsampling (Insertion de zéros)
    ups_L = zeros(len_target, 1);
    ups_L(1:2:end) = sig_L_in(1:length(ups_L)/2);
    
    ups_H = zeros(len_target, 1);
    ups_H(1:2:end) = sig_H_in(1:length(ups_H)/2);
    
    % Filtrage d'interpolation
    filt_L = filter(b_low, 1, ups_L) * 2;
    filt_H = filter(b_high, 1, ups_H) * 2;
    
    % Sommation
    L_min = min(length(filt_L), length(filt_H));
    reconstructed = filt_L(1:L_min) + filt_H(1:L_min);
end

signal_out = reconstructed;

%% 6. Affichage Résultats
t = (0:length(signal)-1)/Fs;

figure('Name', 'Comparaison Temporelle Entrée/Sortie', 'Color', 'w');

t_start = 1.0; 
t_end = 1.05; 

subplot(2,1,1);
plot(t, signal, 'b');
title('Signal d''Entrée (Original) - Zoom 50ms');
xlabel('Temps (s)'); ylabel('Amplitude');
xlim([t_start t_end]);
grid on;

subplot(2,1,2);
plot(t, signal_out, 'r');
title('Signal de Sortie (Reconstruit & Égalisé)');
xlabel('Temps (s)'); ylabel('Amplitude');
xlim([t_start t_end]);
grid on;

figure('Name', 'Visualisation des Sous-bandes (Décomposition)', 'Color', 'w');
sgtitle('Sous-bandes');

labels = {'x0 (Graves - Résidu final)', 'x1 (Bas-Médium)', 'x2 (Médium)', 'x3 (Haut-Médium)', 'x4 (Aigus - Première extraction)'};
colors = lines(5);

for k = 5:-1:1
    sb_idx = k; 
    plot_pos = 6 - k;
    
    subplot(5, 1, plot_pos);
    current_sig = subbands{sb_idx};
    
    plot(current_sig, 'Color', colors(k,:));
    grid on; axis tight;
    
    % Titre dynamique avec nombre d'échantillons
    title(sprintf('Bande %s - Longueur : %d échantillons', labels{sb_idx}, length(current_sig)));
    
    if plot_pos < 5, set(gca, 'XTickLabel', []); end
end
xlabel('Indice Échantillon (Échelle variable selon décimation)');


% --- Figure 3 : Analyse Technique (PSD & VU) ---
figure('Name', 'Analyse Technique', 'Color', 'w');

% VU-Mètre
subplot(2,2,1);
bar(0:4, vu_levels, 'FaceColor', [0 0.4470 0.7410]);
title('VU-mètre (Niveaux RMS)');
xlabel('Bande (x0=Graves -> x4=Aigus)'); ylabel('RMS');
grid on;

% Comparaison Spectrale (PSD)
subplot(2,2,[3 4]);
[p_in, f_p] = pwelch(signal, 1024, 512, 1024, Fs);
[p_out, ~] = pwelch(signal_out, 1024, 512, 1024, Fs);
semilogx(f_p, 10*log10(p_in), 'k', 'LineWidth', 1, 'DisplayName', 'Entrée'); hold on;
semilogx(f_p, 10*log10(p_out), 'r', 'LineWidth', 1.5, 'DisplayName', 'Sortie');
title('Densité Spectrale de Puissance (PSD)');
legend; grid on;
xlabel('Fréquence (Hz)'); ylabel('dB/Hz');
xlim([20 20000]);

fprintf('Terminé. 3 Figures générées pour analyse détaillée.\n');
