# Schelling Segregation

This demo recreates Schelling's segregation result in plain NetLogo. Agents only ask for a modest share of similar neighbors, but repeated moves by unhappy agents still create strongly segregated neighborhoods.

## What Emerges

- Local preferences amplify themselves. A household that only wants `30%` similar neighbors can still contribute to a final pattern where the neighborhood average is closer to `80%` similar.
- The system sorts quickly because each move changes several neighborhoods at once.
- More empty patches usually make segregation appear faster because unhappy agents have more relocation options.

## Files

- `schelling-segregation.nlogo`: standalone NetLogo 7 model with interface widgets and reporters.
- `BehaviorSpace/sweep.xml`: tolerance sweep from `10%` through `50%`.

## How To Run

1. Open `schelling-segregation.nlogo` in NetLogo 7.
2. Leave the defaults (`num-agents = 400`, `similar-wanted = 30`, `empty-rate = 40`) for the validated high-segregation result.
3. Click `setup`, then click `go`.
4. Watch the `Segregation Index`, `Happy Count`, and `Empty Patches` monitors while the plot tracks the run over time.

## BehaviorSpace

Import `BehaviorSpace/sweep.xml` from the NetLogo BehaviorSpace dialog.

- `similar-wanted` sweeps from `10` to `50` in increments of `5`.
- `num-agents` stays at `400`.
- `empty-rate` stays at `40`.
- The experiment stops when the model settles or reaches the built-in `200` tick cap.

## Key Insight

The model demonstrates the Schelling result directly: mild individual tolerance does not imply mild aggregate segregation. With the default settings, a `30%` neighborhood tolerance still settles near `80%` similar neighbors in repeated runs, because decentralized relocation pushes the whole system toward a much more segregated equilibrium.
