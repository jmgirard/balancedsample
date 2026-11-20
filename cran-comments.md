## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Test environments

* Local macOS 27 (aarch64), R 4.6.2: `R CMD check --as-cran`, once with all
  suggested packages installed and once with none of them
  (`_R_CHECK_FORCE_SUGGESTS_=false`).
* GitHub Actions: macOS (release), Windows (release), and Ubuntu (devel,
  release, oldrel-1). TODO: confirm these pass on the release commit.
* win-builder: R-devel. TODO: run and record the result.

## Notes for the reviewers

* twinning, tune, tailor, parsnip, probably, workflows, and ggplot2 are
  suggested packages. Tests and examples that need them skip when they are
  not installed, and the vignette stops early with a note.
