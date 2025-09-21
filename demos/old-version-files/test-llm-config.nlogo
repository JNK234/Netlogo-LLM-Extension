; ABOUTME: Simple test model to debug LLM configuration issues
; ABOUTME: Run this to verify LLM extension is working before running the main model

extensions [ llm ]

globals [
  test-results
]

to setup
  clear-all
  print "=== LLM Configuration Test ==="

  ; Test 1: Try loading config.txt
  test-config-file "config.txt"

  ; Test 2: Try loading config-env.txt
  test-config-file "config-env.txt"

  ; Test 3: Try direct configuration
  test-direct-config

  ; Test 4: Try environment variable
  test-env-variable

  print "=== Test Complete ==="
  print "Check the output above to see which configuration method works"
end

to test-config-file [filename]
  print (word "")
  print (word "Testing: " filename)
  print "------------------------"

  ifelse file-exists? filename [
    print (word "File found: " filename)

    carefully [
      llm:load-config filename
      print "Config loaded successfully"
      print (word "Provider: " llm:get-provider)
      print (word "Model: " llm:get-model)

      ; Try a simple test
      carefully [
        let response llm:chat "Say 'Hello' in one word"
        print (word "Test successful! Response: " response)
      ] [
        print (word "Test failed: " error-message)
        analyze-error error-message
      ]
    ] [
      print (word "Failed to load config: " error-message)
    ]
  ] [
    print (word "File not found: " filename)
  ]
end

to test-direct-config
  print (word "")
  print "Testing: Direct OpenAI Configuration"
  print "------------------------"

  carefully [
    llm:set-provider "openai"
    llm:set-model "gpt-4o-mini"
    print "Provider and model set"
    print "Note: This requires OPENAI_API_KEY environment variable"

    ; Try a simple test
    carefully [
      let response llm:chat "Say 'Hello' in one word"
      print (word "Test successful! Response: " response)
    ] [
      print (word "Test failed: " error-message)
      analyze-error error-message
    ]
  ] [
    print (word "Failed to configure: " error-message)
  ]
end

to test-env-variable
  print (word "")
  print "Testing: Environment Variable Check"
  print "------------------------"

  ; Note: NetLogo doesn't have direct access to environment variables
  ; but the LLM extension should check for them
  print "If you have set OPENAI_API_KEY as an environment variable,"
  print "the direct configuration test above should work."
  print ""
  print "To set environment variable:"
  print "  Mac/Linux: export OPENAI_API_KEY='your-key-here'"
  print "  Windows: set OPENAI_API_KEY=your-key-here"
end

to analyze-error [err]
  print "Error Analysis:"

  ifelse position "404" err != false [
    print "  ✗ 404 Error: API endpoint not found"
    print "  - This usually means the API URL is incorrect"
    print "  - Or the API key format is wrong"
    print "  - For OpenAI, ensure the key starts with 'sk-'"
  ] [
    ifelse position "401" err != false [
      print "  ✗ 401 Error: Authentication failed"
      print "  - API key is missing or invalid"
      print "  - Check if the key is properly set"
    ] [
      ifelse position "429" err != false [
        print "  ✗ 429 Error: Rate limit exceeded"
        print "  - Too many requests"
        print "  - Wait a bit and try again"
      ] [
        ifelse position "500" err != false [
          print "  ✗ 500 Error: Server error"
          print "  - API service is having issues"
          print "  - Try again later"
        ] [
          print (word "  ✗ Unknown error: " err)
        ]
      ]
    ]
  ]
end

to test-simple-chat
  ; Quick test button to check if LLM is working
  print ""
  print "Quick Chat Test:"

  carefully [
    let response llm:chat "What is 2+2? Answer in one word."
    print (word "Success! Response: " response)
  ] [
    print (word "Failed: " error-message)
    analyze-error error-message
  ]
end