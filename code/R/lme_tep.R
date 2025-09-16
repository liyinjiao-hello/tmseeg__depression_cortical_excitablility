## ==========================
## LMM (Type III + Kenward–Roger) → Excel
## ==========================

## 0) Packages (install once if needed)
# install.packages(c("readxl","dplyr","lme4","lmerTest","pbkrtest","emmeans","openxlsx","broom.mixed"))
library(tidyr)  # you use pivot_wider()
library(readxl)
library(dplyr)
library(lme4)
library(lmerTest)    # adds anova() with type=3; will use pbkrtest for KR
library(pbkrtest)    # Kenward–Roger df support
library(emmeans)     # EMMs + Tukey post hocs
library(openxlsx)    # Excel writer
library(broom.mixed) # tidy() for fixed effects if needed

## 1) Paths
in_path  <- "F:/z_outputbackup/Output/Python_output/recheck/TEP_allPeak_recheck.xlsx"
out_path <- "F:/z_outputbackup/Output/Python_output/recheck/tep_statistics/TEP_lme_P60_6.xlsx"

## 2) Read data & basic checks
raw <- read_xlsx(in_path)
names(raw) <- tolower(names(raw))  # normalize names

needed <- c("id","timepoint","tep","value","group")
if (!all(needed %in% names(raw))) {
  stop("Input file must contain columns: id, timepoint, tep, value, group")
}

## 3) Helper: prepare factors for modeling
prep_data <- function(df) {
  df %>%
    mutate(
      participant = factor(id),
      group       = factor(group, levels = c(1,2), labels = c("HC","MDD")),
      timepoint   = factor(timepoint)  # treat 1..7 as categorical
    )
}

## 4) ONE-TEP analysis (Type III + KR) and tidy outputs
run_lmm_type3_kr <- function(df, tep_name) {
  df_tep <- df %>%
    dplyr::filter(tep == tep_name,
                  timepoint %in% 1:6) %>%                 # <-- exclude id 9
    prep_data()
  
  
  # Sum-to-zero contrasts so Type-III is well-defined
  op_old <- options(contrasts = c("contr.sum","contr.poly"))
  on.exit(options(op_old), add = TRUE)
  
  # libs
  library(lme4)
  library(lmerTest)   # <- needed for type=3 and Satterthwaite/KR ddf
  
  # ---- Fit mixed model (REML is fine for Satterthwaite) ----
  model <- lmer(value ~ timepoint * group + (1 | participant),
                data = df_tep, REML = FALSE)
  
  # ---- Type III omnibus tests with Satterthwaite ----
  anova_tbl <- as.data.frame(anova(model, type = 3, ddf = "Satterthwaite"))
  anova_tbl$Effect <- rownames(anova_tbl); rownames(anova_tbl) <- NULL
  anova_tbl <- dplyr::relocate(anova_tbl, Effect)
  names(anova_tbl) <- sub("F.value", "F", names(anova_tbl))
  names(anova_tbl) <- sub("Pr\\(>F\\)", "p", names(anova_tbl))
  
  # ---- emmeans: use KR dfs in post hocs too ----
  emm_options(lmer.df = "Satterthwaite")
  
  # Cell means (EMMs) for each (timepoint, group)
  cell_means <- as.data.frame(emmeans(model, ~ timepoint * group))
  # columns: timepoint, group, emmean, SE, df, lower.CL, upper.CL
  
  ## A) Group differences within each timepoint (HC vs MDD at T1..T7)
  emm_g_by_t <- emmeans(model, ~ group | timepoint)
  g_within_t_contr    <- pairs(emm_g_by_t, adjust = "tukey")
  g_within_t_contr_ci <- as.data.frame(confint(g_within_t_contr, adjust = "tukey"))
  g_within_t_contr_df <- as.data.frame(g_within_t_contr)
  
  # Build means wide: HC/MDD means & SEs per timepoint
  means_wide <- cell_means %>%
    dplyr::select(timepoint, group, emmean, SE) %>%
    tidyr::pivot_wider(
      names_from  = group,
      values_from = c(emmean, SE),
      names_sep   = "_"
    )
  
  # Join contrasts + CIs + means (by timepoint)
  posthoc_group_within_time <- g_within_t_contr_df %>%
    dplyr::rename(estimate = estimate, SE_contrast = SE,
                  df = df, t = t.ratio, p = p.value) %>%
    dplyr::left_join(g_within_t_contr_ci %>%
                       dplyr::select(timepoint, contrast, lower.CL, upper.CL),
                     by = c("timepoint","contrast")) %>%
    dplyr::left_join(means_wide, by = "timepoint") %>%
    dplyr::relocate(timepoint, contrast,
                    emmean_HC, SE_HC, emmean_MDD, SE_MDD,
                    estimate, lower.CL, upper.CL, t, df, p)
  
  ## B) Timepoint differences within each group (all pairwise Ts inside HC and inside MDD)
  emm_t_by_g <- emmeans(model, ~ timepoint | group)
  t_within_g_contr    <- pairs(emm_t_by_g, adjust = "tukey")
  t_within_g_contr_ci <- as.data.frame(confint(t_within_g_contr, adjust = "tukey"))
  
  posthoc_time_within_group <- as.data.frame(t_within_g_contr) %>%
    dplyr::rename(estimate = estimate, SE = SE,
                  df = df, t = t.ratio, p = p.value) %>%
    dplyr::left_join(t_within_g_contr_ci %>%
                       dplyr::select(group, contrast, lower.CL, upper.CL),
                     by = c("group","contrast")) %>%
    dplyr::relocate(group, contrast, estimate, lower.CL, upper.CL, t, df, p)
  
  # Return objects (if you're in a function)
  list(
    anova = anova_tbl,
    cell_means = cell_means,
    posthoc_group_within_time = posthoc_group_within_time,
    posthoc_time_within_group = posthoc_time_within_group
  )
  
}
## 5) Writer: one Omnibus sheet + one PostHoc sheet (with means) per TEP
write_results_for_tep <- function(wb, tep_name, res) {
  # Sheet 1: Omnibus (Type III + KR)
  sh1 <- paste0(tep_name, "_ANOVA_TypeIII_KR")
  addWorksheet(wb, sh1)
  writeData(wb, sh1, res$anova)
  
  # Sheet 2: PostHoc (with means)
  sh2 <- paste0(tep_name, "_PostHoc_with_Means")
  addWorksheet(wb, sh2)
  
  # Block A: Cell means (for transparency & reporting)
  writeData(wb, sh2, data.frame(Header = paste0("EMMs (Cell Means) for ", tep_name)))
  writeData(wb, sh2, res$cell_means, startRow = 3)
  
  # Block B: Group differences within each timepoint (with means on the same row)
  start_row_b <- nrow(res$cell_means) + 6
  writeData(wb, sh2, data.frame(Header = "Group Differences within Each Timepoint (HC vs MDD, Tukey-adjusted)"),
            startRow = start_row_b)
  writeData(wb, sh2, res$posthoc_group_within_time, startRow = start_row_b + 2)
  
  # Block C: Timepoint differences within each group
  start_row_c <- start_row_b + 4 + nrow(res$posthoc_group_within_time)
  writeData(wb, sh2, data.frame(Header = "Timepoint Differences within Each Group (Tukey-adjusted)"),
            startRow = start_row_c)
  writeData(wb, sh2, res$posthoc_time_within_group, startRow = start_row_c + 2)
}

## 6) Run: one TEP or all TEPs
selected_tep <- "P60"   # change as needed
run_all_teps <- FALSE     # set TRUE to process all unique TEPs

wb <- createWorkbook()

if (run_all_teps) {
  for (tp in sort(unique(raw$tep))) {
    res <- run_lmm_type3_kr(raw, tp)
    write_results_for_tep(wb, tp, res)
  }
} else {
  res <- run_lmm_type3_kr(raw, selected_tep)
  write_results_for_tep(wb, selected_tep, res)
}

dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
saveWorkbook(wb, out_path, overwrite = TRUE)

message("Done. Excel saved to: ", out_path)
