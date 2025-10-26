# Run using bin/ci

CI.run do
  step "Setup", "bin/setup"

  step "Style: Ruby", "bin/rubocop"

  step "Assets: JavaScript build", "npm run build"
  step "Assets: CSS build", "npm run build:css"
end
