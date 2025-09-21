# NetLogo Interface Widgets Specification

## Emergent Treasure Hunt Model

### Step-by-Step Widget Implementation Guide

## Phase 1: Core Controls (Required)

### 1. Setup Button

**Add Widget → Button**

- Display text: `setup`
- Commands: `setup`
- Forever?: OFF
- Button type: Observer
- Action key: S
- Position: x=10, y=10

### 2. Go Button

**Add Widget → Button**

- Display text: `go`
- Commands: `go`
- Forever?: ON (continuous execution)
- Button type: Observer
- Action key: G
- Position: x=95, y=10

### 3. Go Once Button

**Add Widget → Button**

- Display text: `go-once`
- Commands: `go`
- Forever?: OFF
- Button type: Observer
- Position: x=180, y=10

## Phase 2: Essential Monitors

### 4. Treasure Status Monitor

**Add Widget → Monitor**

- Reporter: `treasure-status`
- Display name: `Treasure Status`
- Font size: 11
- Position: x=10, y=55

### 5. Ticks Monitor

**Add Widget → Monitor** 

- Reporter: `ticks`
- Display name: `Time Steps`
- Decimal places: 0
- Font size: 11
- Position: x=10, y=100

### 6. Active Hunters Monitor

**Add Widget → Monitor**

- Reporter: `count treasure-hunters`
- Display name: `Active Hunters`
- Decimal places: 0
- Position: x=120, y=100

### 7. Knowledge Summary Monitor

**Add Widget → Monitor**

- Reporter: `knowledge-summary`
- Display name: `Agent Knowledge`
- Font size: 9
- Position: x=10, y=145
- Width: 280

## Phase 3: Configuration Parameters

### 8. Number of Hunters Slider

**Add Widget → Slider**
First, add this global variable to your code:

```netlogo
globals [
  num-hunters  ; Add this to existing globals
  ; ... other globals
]
```

Then create slider:

- Variable: `num-hunters`
- Left value: 2
- Right value: 10
- Increment: 1
- Value: 5
- Display: `Number of Hunters`
- Position: x=10, y=200

Modify setup procedure:

```netlogo
to setup
  ; ... existing setup code ...
  create-treasure-hunters num-hunters [  ; Use slider value
    setup-hunter
  ]
  ; ... rest of setup
end
```

### 9. Communication Range Slider

Add global:

```netlogo
globals [
  communication-range  ; Add this
  ; ... other globals
]
```

Create slider:

- Variable: `communication-range`
- Left value: 1.0
- Right value: 5.0
- Increment: 0.5
- Value: 2.0
- Display: `Communication Range`
- Position: x=10, y=240

Modify detect-nearby-agents:

```netlogo
to detect-nearby-agents
  let nearby-hunters other treasure-hunters in-radius communication-range
  ; ... rest of procedure
end
```

### 10. Confidence Threshold Slider

Add global:

```netlogo
globals [
  confidence-threshold  ; Add this
  ; ... other globals
]
```

Create slider:

- Variable: `confidence-threshold`
- Left value: 0.5
- Right value: 1.0
- Increment: 0.1
- Value: 0.7
- Display: `Confidence to Manifest`
- Position: x=10, y=280

Modify check-treasure-location:

```netlogo
to check-treasure-location
  ; ... existing code ...
  if location-matches? and confidence-level > confidence-threshold [
    attempt-treasure-manifestation
  ]
end
```

## Phase 4: Visual Controls

### 11. Show Trails Switch

Add global:

```netlogo
globals [
  show-trails?  ; Add this
  ; ... other globals
]
```

**Add Widget → Switch**

- Variable: `show-trails?`
- Display: `Show Agent Trails`
- Position: x=10, y=320

Modify setup-hunter:

```netlogo
to setup-hunter
  ; ... existing setup ...
  ifelse show-trails? [
    pen-down
  ] [
    pen-up
  ]
  ; ... rest of setup
end
```

### 12. Show Communications Switch

Add global:

```netlogo
globals [
  show-communications?  ; Add this
  ; ... other globals
]
```

**Add Widget → Switch**

- Variable: `show-communications?`
- Display: `Show Communications`
- Position: x=10, y=350

## Phase 5: Data Visualization

### 13. Agent Confidence Plot

**Add Widget → Plot**

- Name: `Agent Confidence`
- X axis label: `Time`
- Y axis label: `Avg Confidence`
- X min: 0, X max: 500
- Y min: 0, Y max: 1.0
- Position: x=300, y=10
- Size: width=300, height=150

Plot setup commands:

```netlogo
set-current-plot "Agent Confidence"
create-temporary-plot-pen "confidence"
set-plot-pen-color blue
```

Plot update commands:

```netlogo
if any? treasure-hunters [
  plot mean [confidence-level] of treasure-hunters
]
```

### 14. Knowledge Accumulation Plot

**Add Widget → Plot**

- Name: `Knowledge Growth`
- X axis label: `Time`
- Y axis label: `Total Facts`
- X min: 0, X max: 500
- Position: x=300, y=170
- Size: width=300, height=150

Plot update commands:

```netlogo
if any? treasure-hunters [
  plot sum [length learned-facts] of treasure-hunters
]
```

## Phase 6: Strategy Selection

### 15. Default Strategy Chooser

Add global:

```netlogo
globals [
  default-strategy  ; Add this
  ; ... other globals
]
```

**Add Widget → Chooser**

- Variable: `default-strategy`
- Choices: ["random" "methodical" "wall-follower" "mixed"]
- Display: `Default Strategy`
- Position: x=10, y=380

Modify setup-hunter:

```netlogo
to setup-hunter
  ; ... existing setup ...
  ifelse default-strategy = "mixed" [
    set exploration-strategy one-of ["methodical" "random" "wall-follower"]
  ] [
    set exploration-strategy default-strategy
  ]
  ; ... rest of setup
end
```

## Phase 7: LLM Configuration

### 16. LLM Config Input

**Add Widget → Input Box**

- Variable: `llm-config-file`
- Type: String
- Default: "config.txt"
- Display: `LLM Config File`
- Position: x=10, y=420

Add to globals and setup:

```netlogo
globals [
  llm-config-file
  ; ... other globals
]

to setup-llm
  if file-exists? llm-config-file [
    llm:load-config llm-config-file
  ]
end
```

### 17. Output Area

**Add Widget → Output**

- Height: 8 lines
- Font size: 10
- Position: x=10, y=460
- Width: 590

## Implementation Order

1. **Start with Phase 1** - Get basic controls working
2. **Add Phase 2** - Verify monitors display correctly
3. **Implement Phase 3** - Test parameter controls
4. **Add Phase 4** - Enhance visualization
5. **Implement Phase 5** - Add data plots
6. **Complete Phase 6-7** - Add advanced features

## Testing Checklist

- [ ] Setup button initializes maze and agents
- [ ] Go button runs simulation continuously
- [ ] Monitors update correctly
- [ ] Sliders affect agent behavior
- [ ] Plots display data properly
- [ ] Switches toggle visual features
- [ ] LLM integration works (if configured)

## Tips for NetLogo Interface Tab

1. **Arrange widgets logically**: Controls at top, parameters on left, plots on right
2. **Use consistent spacing**: 40-pixel vertical gaps between widget groups
3. **Group related controls**: Use visual spacing or notes to separate sections
4. **Set appropriate ranges**: Test min/max values for stability
5. **Add tooltips**: Right-click widgets → Edit → add helpful notes
6. **Save interface settings**: File → Save As to preserve layout

## Troubleshooting

**If widgets don't appear:**

- Check variable declarations in globals
- Verify procedure names match exactly
- Ensure reporters return appropriate types

**If sliders don't affect behavior:**

- Confirm variables are used in procedures
- Check that setup reinitializes with new values
- Verify ranges are appropriate

**If plots don't update:**

- Add plot update code to go procedure
- Check reporter syntax in plot pens
- Ensure agents exist before plotting

This completes the widget specification. Follow phases 1-7 in order for smooth implementation.
