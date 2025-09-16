import pandas as pd
import numpy as np

# === 1) Load the cortisol data ===
input_path = r"F:\03_Saliva\all_MT.xlsx"  # Adjust path as needed
df = pd.read_excel(input_path)

# === 2) Identify the first four time columns ===
# Assuming the first column is a label and the next four are [0, 0.25, 0.5, 1]
time_cols = df.columns[11:24].astype(float).values  # Time points: [0.0, 0.25, 0.5, 1.0]
cort_vals = df.iloc[:, 11:24].to_numpy(dtype=float)  # Shape (n_subjects, 4)


# === 3) Define a function to compute AUCi with interpolation ===
def auc_increment_with_interp(x, y):
    """
    Compute the area under the curve (AUCi) by:
    1) Linearly interpolating y over x to fill NaNs
    2) Subtracting the baseline (first value) to get incremental change
    3) Integrating the result using the trapezoidal rule
    """
    # Mask of non-NaN points
    valid = ~np.isnan(y)
    if valid.sum() < 2:  # Not enough valid points to interpolate
        return np.nan

    # Linear interpolation on the valid data points
    y_interp = np.interp(x, x[valid], y[valid])

    # Subtract the baseline (first value) to get the incremental change
    y_net = y_interp - y_interp[0]

    # Trapezoidal integration
    return np.trapz(y_net, x)


# === 4) Loop through subjects and compute AUCi for each ===
results = []

for subj_idx, raw_row in enumerate(cort_vals):
    subj_id = subj_idx + 1
    label = f"Subj{subj_id:02d}"

    # Compute AUCi for this subject
    auc_i = auc_increment_with_interp(time_cols, raw_row)

    # Append result to list
    results.append({'Subject': label, 'AUC_increment': auc_i})

# === 5) Create results DataFrame and print/save ===
auc_df = pd.DataFrame(results)

# Display the results
print(auc_df)

# Save results to Excel
output_path = r"F:\03_Saliva\TEMP\mt_temp.xlsx"
auc_df.to_excel(output_path, index=False)
print(f"Saved results to {output_path}")
