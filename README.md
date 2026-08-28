# recipes

Standalone markdown recipes for Claude

## Index

- [`pr/pr-queue-view/pr-queue-view.md`](pr/pr-queue-view/pr-queue-view.md) —
  risk-colored PR queue dashboard for any GitHub repo.
- [`pr/pr-general-scanner/pr-general-scanner.md`](pr/pr-general-scanner/pr-general-scanner.md) —
  scans a repo's PR history to find its moderators' actual requirements and
  behavior patterns, then writes a checklist for submitting a PR that meets
  them.
- [`pr/pr-circuitpython/circuitpython-review.md`](pr/pr-circuitpython/circuitpython-review.md) —
  ready-made `pr-general-scanner` output for `adafruit/circuitpython`: what
  tannewt and dhalbert require before a PR merges, and a pre-flight checklist
  to run against your branch before opening one.
- [`pr/pr-wippersnapper/wippersnapper-pr.md`](pr/pr-wippersnapper/wippersnapper-pr.md) —
  the same, for `adafruit/Adafruit_Wippersnapper_Arduino` (brentru and tyeth).
  Bundled with the maintainers' own
  [`add-sensor-component-v1.SKILL.md`](pr/pr-wippersnapper/add-sensor-component-v1.SKILL.md),
  their upstream guide for the repo's highest-volume PR shape (adding a new
  I2C sensor), which the checklist cites throughout.

## License

GPLv3 — see [LICENSE](LICENSE).
