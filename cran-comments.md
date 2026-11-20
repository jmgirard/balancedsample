## R CMD check results

`R CMD check --as-cran` with `_R_CHECK_CRAN_INCOMING_REMOTE_=true`:
0 errors | 0 warnings | 1 note

* This is a new release.

## Test environments

* Local macOS 27 (aarch64), R 4.6.2, twice: with all suggested packages
  installed, and with twinning, tune, tailor, parsnip, probably, and
  workflows not installed (`_R_CHECK_FORCE_SUGGESTS_=false`). ggplot2 is in
  R's system library there, so it was installed for both runs.
* GitHub Actions: macOS (release), Windows (release), and Ubuntu (devel,
  release, oldrel-1). TODO: confirm these pass on the release commit.
* win-builder: R-devel. TODO: run and record the result.

## Notes for the reviewers

* twinning, tune, tailor, parsnip, probably, workflows, and ggplot2 are
  suggested packages. Tests and examples that need them skip when they are
  not installed, and the vignette stops early with a note.
