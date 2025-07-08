# Words of Truth - Integration Tests

This directory contains comprehensive integration tests for the Words of Truth application. These tests verify that all major user workflows function correctly end-to-end.

## 🎯 Test Coverage

### Main User Flows Tested

1. **Authentication Flow** (`authentication_flow_test.rb`)
   - OAuth2 Google authentication
   - User creation and updates
   - Session management and timeout
   - Admin access controls
   - YouTube authentication integration

2. **Text Notes CRUD** (`text_notes_crud_test.rb`)
   - Complete CRUD operations
   - AI theme detection
   - Korean content support
   - Search and filtering
   - Bulk operations
   - Export functionality

3. **Sermon Automation** (`sermon_automation_test.rb`)
   - URL-based content extraction
   - Content validation and sanitization
   - Batch processing
   - Progress tracking
   - Error handling

4. **Video Generation Workflow** (`video_generation_workflow_test.rb`)
   - Complete video generation pipeline
   - Korean TTS integration
   - Multiple theme support
   - Performance optimization testing
   - Retry mechanisms

5. **Error Handling** (`error_handling_test.rb`)
   - HTTP error responses (404, 500, etc.)
   - Validation errors
   - External service failures
   - Rate limiting
   - Graceful degradation

6. **API Endpoints** (`api_endpoints_test.rb`)
   - RESTful API operations
   - JSON request/response handling
   - Pagination and filtering
   - Authentication and authorization
   - Rate limiting

7. **Security** (`security_test.rb`)
   - XSS protection
   - SQL injection prevention
   - CSRF protection
   - File upload security
   - SSRF protection
   - Security headers

## 🚀 Running Tests

### Prerequisites

```bash
# Install dependencies
bundle install

# Set up test database
rails db:test:prepare

# Ensure test environment is configured
export RAILS_ENV=test
```

### Running All Tests

```bash
# Using the custom test runner
./test/integration/run_integration_tests.rb

# Or using Rails test command
rails test test/integration/
```

### Running Specific Tests

```bash
# Run specific test file
./test/integration/run_integration_tests.rb authentication_flow

# Run by category
./test/integration/run_integration_tests.rb --category api

# Run using Rails
rails test test/integration/authentication_flow_test.rb
```

### Test Categories

- `authentication` - Authentication and session management
- `text_notes` - Text notes CRUD operations
- `sermon` - Sermon automation workflows
- `video` - Video generation processes
- `api` - API endpoint testing
- `security` - Security vulnerability testing
- `error` - Error handling scenarios

## 📊 Performance Monitoring

### Performance Thresholds

The tests monitor performance against these thresholds:

- **Complete Workflow**: 45 seconds
- **Sermon Ingestion**: 10 seconds
- **Video Generation**: 30 seconds
- **Dashboard Response**: 2 seconds
- **API Response**: 1 second
- **Simple Query**: 100ms
- **Complex Query**: 500ms

### Memory Limits

- **Max Memory per Operation**: 50MB
- **Max Total Memory Growth**: 200MB

### Concurrency Testing

- **Max Concurrent Users**: 10
- **Concurrent User Response Time**: 3 seconds

## 🛠 Test Infrastructure

### Helper Modules

- **IntegrationTestHelper**: Performance tracking, test data factories
- **TestDataFactory**: Realistic test data generation
- **RequestStubHelpers**: HTTP request mocking
- **PerformanceAssertions**: Performance validation

### Test Data

The tests use:
- Realistic sermon and text note data
- Korean language content for i18n testing
- Various themes and content types
- Simulated external service responses

### Security Testing

Comprehensive security tests including:
- XSS attack vectors
- SQL injection attempts
- CSRF token validation
- File upload security
- Rate limiting verification
- Session security

## 📈 Test Reports

### Automated Reporting

The test runner generates:
- Performance metrics
- Memory usage statistics
- Success/failure rates
- Detailed timing reports
- JSON results for CI/CD integration

### Example Output

```
🏁 INTEGRATION TEST SUITE SUMMARY
======================================================================
Total runtime: 45.67s
Total tests: 8
✅ Successful: 8
❌ Failed: 0
Success rate: 100.0%

📊 DETAILED RESULTS
----------------------------------------------------------------------
authentication_flow_test            ✅ PASS     8.23s
text_notes_crud_test                ✅ PASS     6.45s
sermon_automation_test              ✅ PASS     9.12s
video_generation_workflow_test      ✅ PASS     12.34s
error_handling_test                 ✅ PASS     4.56s
api_endpoints_test                  ✅ PASS     3.21s
security_test                       ✅ PASS     1.76s
```

## 🔧 Configuration

### Environment Variables

```bash
# Test environment
RAILS_ENV=test

# External service mocking
WEBMOCK_ENABLED=true

# Performance monitoring
PERFORMANCE_TRACKING=true
MEMORY_TRACKING=true
```

### Test Database

The tests use a separate test database and:
- Reset data between tests
- Use transactions for isolation
- Mock external services
- Clean up temporary files

## 📝 Writing New Tests

### Test Structure

```ruby
class NewFeatureTest < ActionDispatch::IntegrationTest
  def setup
    super
    @user = create_authenticated_user
  end

  test "feature workflow" do
    @performance_tracker.track("Feature Test") do
      # Test implementation
    end

    assert_response :success
    # Additional assertions
  end

  private

  def create_authenticated_user
    # Helper method implementation
  end
end
```

### Best Practices

1. **Use performance tracking** for all significant operations
2. **Clean up test data** in teardown methods
3. **Test error conditions** alongside happy paths
4. **Include security validation** in all input handling tests
5. **Use realistic test data** that mirrors production scenarios
6. **Test concurrent operations** for scalability verification

### Adding New Test Categories

1. Create new test file following naming convention
2. Include in test runner's category mapping
3. Add performance thresholds to configuration
4. Update documentation

## 🎭 Mocking and Stubbing

### External Services

- **Sermon Crawling**: HTTP responses stubbed with WebMock
- **Video Generation**: Service calls mocked with realistic delays
- **YouTube API**: OAuth flows and upload responses simulated

### Performance Testing

- **Memory tracking**: Real system memory monitoring
- **Timing validation**: Actual execution time measurement
- **Concurrency testing**: Real thread-based concurrent execution

## 🚨 Troubleshooting

### Common Issues

1. **Test Database Issues**
   ```bash
   rails db:test:prepare
   rails db:reset RAILS_ENV=test
   ```

2. **WebMock Conflicts**
   ```bash
   # Ensure WebMock is properly configured
   WebMock.disable_net_connect!(allow_localhost: true)
   ```

3. **Memory Tracking Failures**
   - Ensure process memory is accessible
   - Check platform-specific memory commands

4. **Performance Test Failures**
   - Review system load during test execution
   - Adjust thresholds for development environment

### Debug Mode

```bash
# Run with verbose output
RAILS_ENV=test rails test test/integration/ --verbose

# Run single test with debugging
ruby -Itest test/integration/authentication_flow_test.rb --debug
```

## 📊 CI/CD Integration

### GitHub Actions

```yaml
- name: Run Integration Tests
  run: |
    bundle exec rails db:test:prepare
    ./test/integration/run_integration_tests.rb
    
- name: Upload Test Results
  uses: actions/upload-artifact@v2
  with:
    name: integration-test-results
    path: test/integration/test_results_*.json
```

### Performance Monitoring

The tests generate metrics suitable for:
- Performance regression detection
- Memory leak identification
- Scalability bottleneck discovery
- Security vulnerability tracking

## 🏆 Success Criteria

Tests are considered successful when:
- ✅ All workflows complete without errors
- ✅ Performance thresholds are met
- ✅ Memory usage stays within limits
- ✅ Security validations pass
- ✅ Concurrent operations handle correctly
- ✅ Error conditions are handled gracefully

---

*Last Updated: January 2025*  
*Test Suite Version: 1.0.0*