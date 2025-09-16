import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('TkAgg')
import matplotlib.pyplot as plt
import statsmodels.formula.api as smf
import os

# ──────────────────────────────────────────────────────────
# 0) Paths
# ──────────────────────────────────────────────────────────
INPUT_XLSX  = r"F:\z_outputbackup\Output\Python_output\recheck\TEP_allPeak_recheck.xlsx"
OUTPUT_XLSX = r"F:\z_outputbackup\Output\Python_output\recheck\tep_statistics\TEP_fitting_group.xlsx"
FIGURE_DIR  = r"F:\z_outputbackup\Output\project_plots\fitting"

# Make sure the output‐figure directory exists
os.makedirs(FIGURE_DIR, exist_ok=True)

# ──────────────────────────────────────────────────────────
# 1) Load & filter data
# ──────────────────────────────────────────────────────────
df = (
    pd.read_excel(INPUT_XLSX)
      .dropna(subset=['Value'])
      .rename(columns=str.strip)
      .query("TEP=='N100' and TimePoint in [1,2,3,4,5,6,7]")
)
df['Group'] = df['Group'].map({1: 'HC', 2: 'MDD'})
hour_map   = {1:1, 2:3, 3:6, 4:10, 5:14, 6:16, 7:24}
df['Time_h'] = df['TimePoint'].map(hour_map)

# ──────────────────────────────────────────────────────────
# 2) Build harmonic regressors
# ──────────────────────────────────────────────────────────
ω = 2 * np.pi / 24
df['cos1'] = np.cos(ω * df['Time_h'])
df['sin1'] = np.sin(ω * df['Time_h'])
df['cos2'] = np.cos(2 * ω * df['Time_h'])
df['sin2'] = np.sin(2 * ω * df['Time_h'])

# ──────────────────────────────────────────────────────────
# 3) For each subject: fit and plot in its own figure
# ──────────────────────────────────────────────────────────
records = []
tfit    = np.linspace(0, 24, 300)

for sid, sub in df.groupby('id'):
    grp = sub['Group'].iat[0]

    # ─────── Fit cosinor OLS on this subject ───────
    mod = smf.ols("Value ~ cos1 + sin1 + cos2 + sin2", data=sub).fit()
    b   = mod.params

    # Mesor
    mesor = b['Intercept']
    # 24h amplitude & acrophase
    amp24     = np.hypot(b['cos1'], b['sin1'])
    phi24_rad = np.arctan2(-b['sin1'], b['cos1'])
    acro24    = (phi24_rad / (2 * np.pi) * 24) % 24

    # 12h amplitude & acrophase
    amp12     = np.hypot(b['cos2'], b['sin2'])
    phi12_rad = np.arctan2(-b['sin2'], b['cos2'])
    acro12    = (phi12_rad / (2 * np.pi) * 12) % 12

    # Goodness‐of‐fit
    r2 = mod.rsquared

    # Save this subject’s parameters
    records.append({
        'id'             : sid,
        'Group'          : grp,
        'mesor'          : mesor,
        'beta_cos1'      : b['cos1'],  'beta_sin1'    : b['sin1'],
        'amp24'          : amp24,      'acrophase24_h': acro24,
        'beta_cos2'      : b['cos2'],  'beta_sin2'    : b['sin2'],
        'amp12'          : amp12,      'acrophase12_h': acro12,
        'R2'             : r2
    })

    # ─────── Create a new figure just for this subject ───────
    fig, ax = plt.subplots(figsize=(6, 4.5))
    ax.set_xlim(0, 24)
    ax.set_xlabel("Time (h)")
    ax.set_ylabel("N100 amplitude (µV)")
    ax.set_title(f"Subject {sid} ({grp})")

    # ─────── Plot raw data points ───────
    ax.scatter(
        sub['Time_h'],
        sub['Value'],
        s=30,
        alpha=0.7,
        edgecolor='k',
        linewidth=0.5
    )

    # ─────── Reconstruct fitted 2-harmonic curve ───────
    yfit = (
        mesor
        + b['cos1'] * np.cos(ω * tfit)
        + b['sin1'] * np.sin(ω * tfit)
        + b['cos2'] * np.cos(2 * ω * tfit)
        + b['sin2'] * np.sin(2 * ω * tfit)
    )
    ax.plot(
        tfit,
        yfit,
        color='gray',
        alpha=0.5
    )

    # ─────── Mark 24 h acrophase point with subject ID ───────
    y_aco = (
        mesor
        + b['cos1'] * np.cos(ω * acro24)
        + b['sin1'] * np.sin(ω * acro24)
        + b['cos2'] * np.cos(2 * ω * acro24)
        + b['sin2'] * np.sin(2 * ω * acro24)
    )
    ax.text(
        acro24,
        y_aco,
        str(sid),
        fontsize=8,
        color='black',
        ha='left',
        va='bottom'
    )

    # Optional: annotate R² somewhere on the plot
    ax.text(
        0.98, 0.02,
        f"R² = {r2:.2f}",
        fontsize=8,
        ha='right',
        va='bottom',
        transform=ax.transAxes
    )

    plt.tight_layout()

    # ─────── Save this subject’s figure ───────
    fig_path = os.path.join(FIGURE_DIR, f"Subject_{sid}_cosinor.png")
    fig.savefig(fig_path, dpi=150)
    plt.close(fig)  # close it to free memory

# ──────────────────────────────────────────────────────────
# 4) Write all subjects’ parameters to Excel
# ──────────────────────────────────────────────────────────
subj_df = pd.DataFrame(records)
with pd.ExcelWriter(OUTPUT_XLSX, engine='openpyxl') as writer:
    subj_df.to_excel(writer, sheet_name='Subject_Params', index=False)

print("✅ Done. Subject parameters written to Excel.")
print(f"   Figures saved in: {FIGURE_DIR}")
