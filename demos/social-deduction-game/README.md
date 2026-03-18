# Social Deduction Game (Undercover / Spy Words)

## Hypothesis

LLM agents will correctly identify spies at below-chance accuracy because they struggle to integrate cross-round description patterns into coherent suspicion, while LLM spies will be caught faster than chance because they produce descriptions that are subtly misaligned with the majority word.

## Source

Inspired by LLMArena (ACL 2024) — social deduction games as an evaluation framework for LLM reasoning and theory of mind.

## Game Mechanics

1. **Setup**: N players arranged in a circle. One is randomly assigned the "spy word"; the rest share the "regular word". Words are similar but distinct (e.g., apple vs pear).
2. **Description Phase**: Each alive player describes their word in 1-2 sentences without saying it.
3. **Voting Phase**: Each alive player votes for who they think is the spy based on descriptions.
4. **Elimination**: The player with the most votes is eliminated.
5. **Win Condition**: Regulars win if the spy is eliminated. The spy wins if only 2 players remain or max rounds are reached.

## Word Pairs (3 difficulty tiers)

| Difficulty | Regular Word | Spy Word |
|-----------|-------------|----------|
| High (hard to detect) | apple/guitar/coffee/pillow/ocean | pear/ukulele/tea/cushion/lake |
| Medium | bicycle/painting/castle/penguin/candle | motorcycle/photograph/mansion/duck/flashlight |
| Low (easy to detect) | airplane/forest/piano/book/snowflake | submarine/desert/drums/television/raindrop |

## Files

| File | Purpose |
|------|---------|
| `social-deduction-game.nlogox` | Main NetLogo model |
| `config.txt` | LLM provider configuration (default: Ollama) |
| `description-template.yaml` | Prompt template for description phase |
| `README.md` | This file |

## Setup

1. Install the LLM extension (see main repo README)
2. Configure `config.txt` with your preferred provider
3. Open `social-deduction-game.nlogox` in NetLogo 7.0.3+
4. Click **Setup** to initialize players
5. Click **Go** to run the full game, or **Step** for one round at a time

## Interface Controls

- **num-players**: Number of players (4-8, default 6)
- **max-rounds**: Maximum rounds before spy wins (3-10, default 6)
- **difficulty-level**: Word pair similarity ("low"/"medium"/"high")
- **show-descriptions?**: Display description speech bubbles
- **show-votes?**: Display vote targets
- **auto-reveal?**: Reveal spy identity when game ends

## Expected Results

- **Detection rate**: Expected below 1/N chance (where N = number of players)
- **Spy survival**: Spy descriptions tend to be subtly "off", leading to faster-than-chance detection in some rounds, but overall detection accuracy remains low because regulars struggle to synthesize cross-round patterns
- **Difficulty effect**: Higher difficulty (more similar words) should decrease detection rate
