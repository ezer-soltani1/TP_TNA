%% TNA - Seance 3
clear; close all; clc;

%% 1. Chargement et Initialisation
fprintf('--- Chargement des données ---\n');
if exist('pcm_48k.mat', 'file')
    load('pcm_48k.mat');
end


N = length(signal);
t = (0:N-1)/Fs;

% --- Définition des 5 bandes (Sélection ISO espacée de 2 octaves) ---
% Cela permet de couvrir Basses, Bas-médiums, Médiums, Haut-médiums, Aigus
f_centers = [62.5, 250, 1000, 4000, 16000];
num_bands = length(f_centers);

% Gains de l\'égaliseur (en dB) - Exemple : "V shape"
gains_dB = [6, -3, -6, -3, 6]; 
gains_lin = 10.^(gains_dB/20);

fprintf('Fréquences centrales : %s Hz\n', mat2str(f_centers));
fprintf('Gains appliqués (dB) : %s\n', mat2str(gains_dB));

%% 2. Approche Temporelle : Banc de Filtres IIR
fprintf('\n--- Approche Temporelle (IIR Butterworth) ---\n');
tic;

signal_out_time = zeros(size(signal));
vu_meter_time = zeros(num_bands, 1);

% Pour l\'affichage de la réponse en fréquence globale
freq_response_total = zeros(1, 4096); 
[~, W_freq] = freqz(1, 1, 4096, Fs); % Initialisation vecteur fréquence

% Création figure pour Bode
figure('Name', 'Réponse des Filtres IIR (Temporel)', 'Color', 'w');
hold on; grid on;

% Facteur de qualité Q pour définir la largeur de bande
% Pour 2 octaves, la largeur est plus grande. 
% BW (Bandwidth) en octaves. Si espacement de 2 octaves, on veut BW ~ 2.
BW = 2;
% Formule simplifiée pour les fréquences de coupure à partir de BW :
% f_low = fc / (2^(BW/2))
% f_high = fc * (2^(BW/2))

for i = 1:num_bands
    fc = f_centers(i);
    f_low = fc / (2^(BW/2));
    f_high = fc * (2^(BW/2));
    
    % Sécurité Nyquist
    if f_high >= Fs/2
        f_high = Fs/2 - 1; 
    end
    
    % Conception du filtre IIR Ordre 2 (Pente douce, suffisant pour EQ musical)
    [b, a] = butter(2, [f_low f_high]/(Fs/2), 'bandpass');
    
    % Filtrage
    band_signal = filter(b, a, signal);
    
    % Sommation pondérée (Égalisation)
    signal_out_time = signal_out_time + (band_signal * gains_lin(i));
    
    % Calcul VU-mètre (RMS)
    vu_meter_time(i) = rms(band_signal);
    
    % Trace Bode individuel
    [H, ~] = freqz(b, a, 4096, Fs);
    plot(W_freq, 20*log10(abs(H)), 'LineWidth', 1.5, 'DisplayName', sprintf('%g Hz', fc));
    
    % Accumulation réponse globale (Approximation magnitude)
    freq_response_total = freq_response_total + abs(H)' * gains_lin(i);
end

% Trace réponse globale théorique de l\'EQ
plot(W_freq, 20*log10(freq_response_total), 'k--', 'LineWidth', 2, 'DisplayName', 'Global EQ');
legend show;
title('Banc de filtres IIR Butterworth (5 Bandes)');
xlabel('Fréquence (Hz)'); ylabel('Gain (dB)');
set(gca, 'XScale', 'log'); xlim([20 20000]); ylim([-60 15]);

time_cost = toc;
fprintf('Temps de calcul (Temporel) : %.4f s\n', time_cost);

%% 3. Approche Fréquentielle : FFT
fprintf('\n--- Approche Fréquentielle (FFT) ---\n');
tic;

N_fft = 2^nextpow2(N);
SIGNAL = fft(signal, N_fft);
f = (0:N_fft-1)*(Fs/N_fft);

% Création du masque
half_N = N_fft/2 + 1;
indices_pos = 1:half_N;
freqs_pos = f(indices_pos);
mask_pos = zeros(half_N, 1);

% Filtres rectangulaires (Idéal) dans le domaine fréquentiel
% Attention : Cela crée des oscillations temporelles (Phénomène de Gibbs)
% Pour le TP, cela illustre parfaitement la différence "Idéal vs Réel"
for i = 1:num_bands
    fc = f_centers(i);
    f_low = fc / (2^(BW/2));
    f_high = fc * (2^(BW/2));
    
    idx = (freqs_pos >= f_low) & (freqs_pos < f_high);
    mask_pos(idx) = mask_pos(idx) + gains_lin(i);
end

% Si des fréquences ne sont couvertes par aucune bande (trous), on peut laisser à 0 ou mettre à 1 (flat)
% Ici, comme on espace de 2 octaves avec BW=2, c'est contigu.
% On gère les "trous" éventuels en mettant le gain à 1 (0dB) par défaut là où c'est 0 ?
% Pour un égaliseur graphique strict, on ne touche qu'aux bandes définies.
% Mais attention, si mask reste à 0 entre les bandes, on coupe le son !
% Amélioration : Initialiser le masque à une valeur de base très faible (stopband) ou interpoler.
% ICI : On suppose que les bandes sont contiguës ou qu'on veut isoler ces bandes.
% Pour éviter le silence entre bandes si elles ne se touchent pas parfaitement :
mask_pos(mask_pos == 0) = 0.001; % -60dB pour le "reste" ou 1 pour "bypass"

% Symétrie
mask_full = zeros(N_fft, 1);
mask_full(1:half_N) = mask_pos;
mask_full(half_N+1:end) = flipud(mask_pos(2:end-1));

SIGNAL_OUT = SIGNAL .* mask_full;
signal_out_freq = real(ifft(SIGNAL_OUT, N_fft));
signal_out_freq = signal_out_freq(1:N);

freq_cost = toc;
fprintf('Temps de calcul (Fréquentiel) : %.4f s\n', freq_cost);

%% 4. Comparaison & VU-mètre
figure('Name', 'Résultats EQ 5 Bandes', 'Color', 'w');

% VU-mètre
subplot(2,1,1);
bar(1:num_bands, 20*log10(vu_meter_time), 'FaceColor', [0.2 0.6 0.8]);
set(gca, 'XTick', 1:num_bands, 'XTickLabel', num2cell(f_centers));
xlabel('Fréquences (Hz)'); ylabel('Niveau (dB)');
title('VU-mètre (Calcul Temporel)');
grid on;

% Comparaison spectrale finale
subplot(2,1,2);
[Pxx_in, F] = pwelch(signal, 1024, 512, 1024, Fs);
[Pxx_out_time, ~] = pwelch(signal_out_time, 1024, 512, 1024, Fs);
[Pxx_out_freq, ~] = pwelch(signal_out_freq, 1024, 512, 1024, Fs);

semilogx(F, 10*log10(Pxx_in), 'g', 'DisplayName', 'Original'); hold on;
semilogx(F, 10*log10(Pxx_out_time), 'b', 'DisplayName', 'IIR (Temporel)');
semilogx(F, 10*log10(Pxx_out_freq), 'r--', 'DisplayName', 'FFT (Fréquentiel)');
legend; grid on; xlim([20 20000]);
xlabel('Fréquence (Hz)'); ylabel('PSD (dB/Hz)');
title('Comparaison des Spectres de Sortie');

fprintf('Script terminé.\n');
