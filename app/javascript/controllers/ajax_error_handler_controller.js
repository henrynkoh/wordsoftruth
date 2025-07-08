// AJAX Error Handler Stimulus Controller for background job feedback
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    retryAttempts: { type: Number, default: 3 },
    retryDelay: { type: Number, default: 2000 },
    progressUrl: String,
    pollInterval: { type: Number, default: 1000 }
  }

  connect() {
    this.setupGlobalAjaxHandlers()
    this.retryCount = 0
    this.isPolling = false
  }

  disconnect() {
    this.stopPolling()
  }

  setupGlobalAjaxHandlers() {
    // Handle Rails UJS AJAX errors
    document.addEventListener('ajax:error', this.handleAjaxError.bind(this))
    document.addEventListener('ajax:success', this.handleAjaxSuccess.bind(this))
    
    // Handle fetch errors
    const originalFetch = window.fetch
    window.fetch = (...args) => {
      return originalFetch(...args)
        .then(response => {
          if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`)
          }
          return response
        })
        .catch(error => {
          this.handleFetchError(error, args[0])
          throw error
        })
    }
  }

  handleAjaxError(event) {
    const xhr = event.detail[0]
    const status = xhr.status
    const response = xhr.responseText
    
    let errorData = {}
    try {
      errorData = JSON.parse(response)
    } catch (e) {
      errorData = { error: response || '알 수 없는 오류가 발생했습니다' }
    }
    
    // Extract error information
    const errorMessage = errorData.error || errorData.message || '요청 처리 중 오류가 발생했습니다'
    const errorId = errorData.error_id || this.generateErrorId()
    
    // Log error details
    console.error('AJAX Error:', {
      status,
      message: errorMessage,
      errorId,
      url: xhr.responseURL,
      response: errorData
    })
    
    // Handle different error types
    switch (status) {
      case 0:
        this.handleNetworkError(errorMessage, errorId)
        break
      case 401:
        this.handleAuthError(errorData)
        break
      case 403:
        this.handleAuthorizationError(errorMessage)
        break
      case 404:
        this.handleNotFoundError(errorMessage)
        break
      case 422:
        this.handleValidationError(errorData)
        break
      case 429:
        this.handleRateLimitError(errorMessage)
        break
      case 500:
      case 502:
      case 503:
      case 504:
        this.handleServerError(errorMessage, errorId, status)
        break
      default:
        this.handleGenericError(errorMessage, errorId, status)
    }
    
    // Stop any ongoing operations
    this.stopPolling()
  }

  handleAjaxSuccess(event) {
    // Reset retry counter on success
    this.retryCount = 0
    
    const response = event.detail[0]
    if (response && response.success === false) {
      // Handle API errors returned as successful HTTP responses
      this.handleApiError(response)
    }
  }

  handleFetchError(error, url) {
    console.error('Fetch Error:', error, 'URL:', url)
    
    if (error.name === 'TypeError' && error.message.includes('Failed to fetch')) {
      this.handleNetworkError('네트워크 연결을 확인해주세요', this.generateErrorId())
    } else {
      this.handleGenericError(error.message, this.generateErrorId())
    }
  }

  handleNetworkError(message, errorId) {
    if (this.retryCount < this.retryAttemptsValue) {
      this.showRetryMessage(message, errorId)
      this.scheduleRetry()
    } else {
      this.showError('네트워크 연결에 문제가 있습니다. 인터넷 연결을 확인하고 페이지를 새로고침해주세요.', errorId)
    }
  }

  handleAuthError(errorData) {
    this.showError('로그인이 필요합니다. 다시 로그인해주세요.')
    
    // Redirect to login if specified
    if (errorData.redirect_to) {
      setTimeout(() => {
        window.location.href = errorData.redirect_to
      }, 2000)
    }
  }

  handleAuthorizationError(message) {
    this.showError(message || '접근 권한이 없습니다.')
  }

  handleNotFoundError(message) {
    this.showError(message || '요청하신 리소스를 찾을 수 없습니다.')
  }

  handleValidationError(errorData) {
    const errors = errorData.errors || [errorData.error || '입력 정보를 확인해주세요']
    
    if (Array.isArray(errors)) {
      errors.forEach(error => this.showWarning(error))
    } else {
      this.showWarning(errorData.error || '입력 정보를 확인해주세요')
    }
  }

  handleRateLimitError(message) {
    this.showWarning(message || '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.')
  }

  handleServerError(message, errorId, status) {
    const baseMessage = '서버에 일시적인 문제가 발생했습니다.'
    
    if (this.retryCount < this.retryAttemptsValue) {
      this.showRetryMessage(`${baseMessage} 자동으로 재시도합니다.`, errorId)
      this.scheduleRetry()
    } else {
      this.showError(`${baseMessage} 문제가 지속되면 관리자에게 문의해주세요.`, errorId)
    }
  }

  handleGenericError(message, errorId, status) {
    this.showError(message || '예상치 못한 오류가 발생했습니다.', errorId)
  }

  handleApiError(response) {
    const message = response.error || response.message || 'API 오류가 발생했습니다'
    const errorId = response.error_id || this.generateErrorId()
    
    if (response.errors && Array.isArray(response.errors)) {
      response.errors.forEach(error => this.showWarning(error))
    } else {
      this.showError(message, errorId)
    }
  }

  scheduleRetry() {
    this.retryCount++
    const delay = this.retryDelayValue * Math.pow(2, this.retryCount - 1) // Exponential backoff
    
    setTimeout(() => {
      this.showInfo(`재시도 중... (${this.retryCount}/${this.retryAttemptsValue})`)
      // Trigger the retry mechanism here
      this.dispatchRetryEvent()
    }, delay)
  }

  dispatchRetryEvent() {
    const retryEvent = new CustomEvent('ajax:retry', {
      detail: { 
        attempt: this.retryCount,
        maxAttempts: this.retryAttemptsValue
      }
    })
    this.element.dispatchEvent(retryEvent)
  }

  // Progress polling for background jobs
  startProgressPolling(jobId, progressUrl) {
    if (this.isPolling) return
    
    this.isPolling = true
    this.jobId = jobId
    this.progressUrl = progressUrl || this.progressUrlValue
    
    this.pollProgress()
  }

  stopPolling() {
    this.isPolling = false
    if (this.pollTimeout) {
      clearTimeout(this.pollTimeout)
    }
  }

  pollProgress() {
    if (!this.isPolling) return
    
    fetch(`${this.progressUrl}?job_id=${this.jobId}`)
      .then(response => response.json())
      .then(data => {
        this.updateProgress(data)
        
        if (data.status === 'completed' || data.status === 'failed') {
          this.stopPolling()
          this.handleJobCompletion(data)
        } else {
          this.scheduleNextPoll()
        }
      })
      .catch(error => {
        console.error('Progress polling error:', error)
        this.handleProgressError(error)
      })
  }

  scheduleNextPoll() {
    this.pollTimeout = setTimeout(() => {
      this.pollProgress()
    }, this.pollIntervalValue)
  }

  updateProgress(data) {
    const progressEvent = new CustomEvent('progress:update', {
      detail: data
    })
    this.element.dispatchEvent(progressEvent)
    
    // Update progress UI if elements exist
    const progressBar = document.querySelector('[data-progress-bar]')
    const progressText = document.querySelector('[data-progress-text]')
    
    if (progressBar && data.percentage !== undefined) {
      progressBar.style.width = `${data.percentage}%`
    }
    
    if (progressText && data.message) {
      progressText.textContent = data.message
    }
  }

  handleJobCompletion(data) {
    if (data.status === 'completed') {
      this.showSuccess(data.message || '작업이 완료되었습니다!')
    } else if (data.status === 'failed') {
      this.showError(data.error || '작업 처리 중 오류가 발생했습니다', data.error_id)
    }
    
    const completionEvent = new CustomEvent('job:completed', {
      detail: data
    })
    this.element.dispatchEvent(completionEvent)
  }

  handleProgressError(error) {
    console.error('Progress error:', error)
    this.stopPolling()
    this.showWarning('진행 상황을 확인할 수 없습니다. 페이지를 새로고침해주세요.')
  }

  // Flash message helpers
  showSuccess(message, options = {}) {
    if (window.FlashMessages) {
      window.FlashMessages.success(message, options)
    } else {
      console.log('Success:', message)
    }
  }

  showError(message, errorId = null) {
    const fullMessage = errorId ? `${message} (오류 ID: ${errorId})` : message
    
    if (window.FlashMessages) {
      window.FlashMessages.error(fullMessage, { autoDismiss: false })
    } else {
      console.error('Error:', fullMessage)
    }
  }

  showWarning(message) {
    if (window.FlashMessages) {
      window.FlashMessages.warning(message)
    } else {
      console.warn('Warning:', message)
    }
  }

  showInfo(message) {
    if (window.FlashMessages) {
      window.FlashMessages.info(message)
    } else {
      console.info('Info:', message)
    }
  }

  showRetryMessage(message, errorId) {
    const fullMessage = `${message} ${errorId ? `(오류 ID: ${errorId})` : ''}`
    this.showWarning(fullMessage)
  }

  generateErrorId() {
    const timestamp = new Date().toISOString().slice(0, 10).replace(/-/g, '')
    const random = Math.random().toString(36).substr(2, 4).toUpperCase()
    return `ERR-${timestamp}-${random}`
  }

  // Public methods for manual error handling
  retry() {
    if (this.retryCount < this.retryAttemptsValue) {
      this.scheduleRetry()
    }
  }

  reset() {
    this.retryCount = 0
    this.stopPolling()
  }
}