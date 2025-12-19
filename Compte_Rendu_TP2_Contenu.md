# Compte-Rendu TNA - Séance 2 : Convertisseur de Fréquence d'Échantillonnage (SRC)
*Structure suggérée pour le support de présentation (PPTX)*

---

## Slide 1 : Titre
**Titre :** Conversion de Fréquence d'Échantillonnage (SRC)
**Sous-titre :** De l'approche naïve à l'architecture polyphasée
**Auteurs :** [Vos Noms]
**Date :** 19 Décembre 2025
**Contexte :** TP Traitements Numériques Avancés (ENSEA)

---

## Slide 2 : Contexte et Objectifs
**Objectif :** Convertir un flux audio du standard CD ($F_{in} = 44.1$ kHz) vers le standard Studio/Vidéo ($F_{out} = 48$ kHz).

**Le Défi Mathématique :**
* Le rapport de conversion n'est pas entier :
  $$ \frac{F_{out}}{F_{in}} = \frac{48000}{44100} = \frac{160}{147} $$
* Cela implique une chaîne de traitement rationnelle :
  1.  **Interpolation** par un facteur $L = 160$.
  2.  **Décimation** par un facteur $M = 147$.

**Enjeu Industriel :**
* Maintenir une qualité audio parfaite (pas d'aliasing).
* Optimiser le coût de calcul pour une implémentation temps-réel.

---

## Slide 3 : Chaîne de Traitement Théorique (Jalon 1)
**Architecture Naïve :**
`Signal (44.1k) --> [Expansion L=160] --> [Filtre Passe-Bas] --> [Décimation M=147] --> Signal (48k)`

**Contraintes Critiques :**
1.  **Fréquence Intermédiaire :**
    $$ F_{inter} = 44.1 \text{ kHz} \times 160 = 7.056 \text{ MHz} $$
    *Conséquence :* Le processeur doit traiter 7 millions d'échantillons par seconde.
2.  **Filtrage Anti-Repliement :**
    *   Doit couper impérativement avant la fréquence de Nyquist la plus basse ($F_{c} = 22.05$ kHz).
    *   À 7 MHz, cette fréquence est très basse ($\approx 0.006 \pi$), nécessitant un filtre d'ordre très élevé (estimé à $N \approx 4000$ taps).

---

## Slide 4 : Résultats de l'Approche Naïve
*(Insérer ici les figures générées par `TNA_Seance2_Etapes_Intermediaires.m`)*

**Analyse Temporelle :**
*   **Expansion :** Insertion de 159 zéros entre chaque échantillon (Visible sur les zooms).
*   **Filtrage :** Reconstruction parfaite de l'enveloppe analogique. Le filtre "relie les points".
*   **Décimation :** Prélèvement correct des nouveaux échantillons (points verts sur la courbe bleue).

**Analyse Spectrale :**
*   L'expansion crée des images spectrales (répliques du spectre) tous les 44.1 kHz.
*   Le filtre supprime efficacement ces images (atténuation > 60dB) pour ne garder que la bande de base.

**Conclusion Jalon 1 :** La méthode fonctionne mathématiquement mais est inefficace.

---

## Slide 5 : Analyse Critique des Performances
**Le Problème du Gaspillage :**
*   Après l'expansion, le signal contient **99.3% de zéros** ($159/160$).
*   Lors de la convolution (Filtrage), le processeur effectue des millions de multiplications du type :
    $$ y[n] = \sum h[k] \cdot x[n-k] $$
*   Puisque la majorité des $x[n]$ sont nuls, **la quasi-totalité des calculs donne 0**.
*   De plus, l'étape suivante (Décimation) jette 146 échantillons calculés sur 147.

**Verdict :** Gaspillage massif de ressources CPU et Mémoire. Impossible à implémenter sur cible embarquée.

---

## Slide 6 : L'Approche Optimale (Jalon 2/3)
**Solution : Architecture Polyphasée**
*   Utilisée par la fonction MATLAB `resample`.
*   **Principe :**
    1.  Ne pas effectuer les multiplications par zéro.
    2.  Ne calculer que les échantillons qui seront conservés par la décimation.
*   Cela revient à décomposer le grand filtre unique en une banque de $L$ sous-filtres plus petits.

**Avantage :**
*   Le traitement se fait virtuellement à la fréquence d'entrée/sortie, et non à 7 MHz.
*   Réduction drastique de la complexité algorithmique.

---

## Slide 7 : Comparaison des Performances
*(Remplir ce tableau avec les résultats de `TNA_Seance2_Performance.m`)*

| Métrique | Approche Naïve (Est.) | Approche Polyphasée (resample) |
| :--- | :--- | :--- |
| **Fréquence de Calcul** | 7.056 MHz | ~48 kHz |
| **Complexité (Ordre Filtre)** | ~4000 coefficients | (Géré par fenêtrage Kaiser) |
| **Temps d'exécution (5s son)** | *[Insérer Temps Naïf]* s | *[Insérer Temps Opti]* s |
| **Facteur d'accélération** | 1x (Référence) | **x[Insérer Gain]** (ex: x100) |

**Observation :** L'approche polyphasée est plusieurs ordres de grandeur plus rapide, rendant le SRC viable pour le temps réel.

---

## Slide 8 : Conclusion
1.  **Faisabilité :** La conversion 44.1 vers 48 kHz est mathématiquement rigoureuse grâce à l'interpolation rationnelle $L/M$.
2.  **Qualité :** L'analyse spectrale prouve l'absence d'aliasing et la préservation du signal utile.
3.  **Implémentation :** L'approche naïve est une impasse technologique. Seule l'approche polyphasée (implémentée dans `resample`) permet d'atteindre les performances requises par l'industrie audio.

---
*Ce document sert de base pour la création du fichier PowerPoint `TNA2-ESE-BENTEKFA-SOLTANI.pptx`.*