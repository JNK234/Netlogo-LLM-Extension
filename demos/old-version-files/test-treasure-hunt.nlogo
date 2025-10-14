; ABOUTME: Simple test script to verify the emergent treasure hunt demo functionality
; ABOUTME: Tests basic maze generation, agent creation, and simulation startup

extensions [llm]

; Simple test to verify the treasure hunt demo loads and runs
to test-treasure-hunt-demo
  ; Test maze generation
  setup

  ; Verify basic world state
  if count treasure-hunters != 5 [
    print "ERROR: Expected 5 treasure hunters, found " count treasure-hunters
  ]

  ; Verify maze has walls and paths
  let wall-count count patches with [wall?]
  let path-count count patches with [not wall?]

  if wall-count = 0 [
    print "ERROR: No walls found in maze"
  ]

  if path-count = 0 [
    print "ERROR: No paths found in maze"
  ]

  ; Verify agents have knowledge fragments
  ask treasure-hunters [
    if knowledge-fragment = "" [
      print "ERROR: Agent missing knowledge fragment"
    ]
  ]

  ; Run a few ticks to test basic functionality
  repeat 10 [
    go
  ]

  print "Basic treasure hunt demo test completed successfully!"
end
