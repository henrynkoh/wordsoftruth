// Progress Tracker Stimulus Controller for background job monitoring
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progressBar", "progressText", "statusMessage", "currentStep", "eta"]
  static values = { 
    jobId: String,
    progressUrl: String,
    pollInterval: { type: Number, default: 1000 },
    autoStart: { type: Boolean, default: true },
    maxRetries: { type: Number, default: 5 },
    showEta: { type: Boolean, default: true }
  }

  connect() {
    this.isPolling = false
    this.retryCount = 0
    this.startTime = Date.now()
    this.lastProgress = 0
    this.progressHistory = []
    
    if (this.autoStartValue && this.jobIdValue) {
      this.startTracking()
    }
  }

  disconnect() {
    this.stopTracking()
  }

  startTracking(jobId = null) {
    if (jobId) this.jobIdValue = jobId
    
    if (!this.jobIdValue) {
      console.error('No job ID provided for progress tracking')
      return
    }
    
    this.isPolling = true
    this.retryCount = 0
    this.startTime = Date.now()
    this.updateStatus('시작 중...', 0)
    
    this.pollProgress()
  }

  stopTracking() {
    this.isPolling = false
    if (this.pollTimeout) {
      clearTimeout(this.pollTimeout)
    }
  }

  pollProgress() {
    if (!this.isPolling) return

    const progressUrl = this.progressUrlValue || `/api/v1/progress/status`
    
    fetch(`${progressUrl}?job_id=${this.jobIdValue}`, {
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }
      return response.json()
    })
    .then(data => {
      this.handleProgressUpdate(data)
      this.retryCount = 0 // Reset retry count on success
      
      if (this.shouldContinuePolling(data)) {
        this.scheduleNextPoll()
      } else {
        this.handleCompletion(data)
      }
    })
    .catch(error => {
      this.handleProgressError(error)
    })
  }

  handleProgressUpdate(data) {
    const { 
      status, 
      percentage, 
      message, 
      current_step, 
      total_steps,
      error,
      metadata = {}
    } = data

    // Update progress bar
    if (percentage !== undefined) {
      this.updateProgress(percentage)
      this.calculateETA(percentage)
    }

    // Update status message
    if (message) {
      this.updateStatusMessage(message)
    }

    // Update current step
    if (current_step !== undefined && total_steps !== undefined) {
      this.updateCurrentStep(current_step, total_steps)
    }

    // Handle different statuses
    switch (status) {
      case 'processing':
        this.handleProcessingStatus(data)
        break
      case 'completed':
        this.handleSuccessStatus(data)
        break
      case 'failed':
        this.handleFailureStatus(data)
        break
      case 'cancelled':
        this.handleCancelledStatus(data)
        break
    }

    // Store progress for ETA calculation
    this.progressHistory.push({
      timestamp: Date.now(),
      percentage: percentage || 0
    })

    // Keep only last 10 data points
    if (this.progressHistory.length > 10) {
      this.progressHistory.shift()
    }

    // Dispatch progress event
    this.dispatchProgressEvent('progress:updated', data)
  }

  handleProcessingStatus(data) {
    const { percentage, message } = data
    
    // Show specific processing messages
    const processingMessages = {
      0: '작업을 준비하고 있습니다...',
      10: '콘텐츠를 분석하고 있습니다...',
      25: '테마를 적용하고 있습니다...',
      50: '영상을 생성하고 있습니다...',
      75: '최종 처리 중입니다...',
      90: '거의 완료되었습니다...'
    }

    if (!message) {
      const closestKey = Object.keys(processingMessages)
        .map(Number)
        .reduce((prev, curr) => 
          Math.abs(curr - (percentage || 0)) < Math.abs(prev - (percentage || 0)) ? curr : prev
        )
      
      this.updateStatusMessage(processingMessages[closestKey])
    }
  }

  handleSuccessStatus(data) {
    this.updateProgress(100)
    this.updateStatusMessage(data.message || '✅ 완료되었습니다!')
    this.hideETA()
    
    // Show success animation
    this.showSuccessAnimation()
    
    this.dispatchProgressEvent('progress:completed', data)
  }

  handleFailureStatus(data) {
    this.updateStatusMessage(`❌ ${data.error || '처리 중 오류가 발생했습니다'}`)
    this.showRetryOption()
    
    this.dispatchProgressEvent('progress:failed', data)
  }

  handleCancelledStatus(data) {
    this.updateStatusMessage('⏹️ 작업이 취소되었습니다')
    this.dispatchProgressEvent('progress:cancelled', data)
  }

  handleProgressError(error) {
    console.error('Progress polling error:', error)
    
    this.retryCount++
    
    if (this.retryCount < this.maxRetriesValue) {
      this.updateStatusMessage(`연결 재시도 중... (${this.retryCount}/${this.maxRetriesValue})`)
      
      // Exponential backoff
      const delay = Math.min(1000 * Math.pow(2, this.retryCount - 1), 10000)
      setTimeout(() => {
        if (this.isPolling) {
          this.pollProgress()
        }
      }, delay)
    } else {
      this.updateStatusMessage('❌ 진행 상황을 확인할 수 없습니다')
      this.showRetryOption()
      this.stopTracking()
    }
  }

  shouldContinuePolling(data) {
    const { status } = data
    return this.isPolling && !['completed', 'failed', 'cancelled'].includes(status)
  }

  handleCompletion(data) {
    this.stopTracking()
    
    // Auto-refresh page if specified
    if (data.redirect_url) {
      setTimeout(() => {
        window.location.href = data.redirect_url
      }, 2000)
    } else if (data.refresh_page) {
      setTimeout(() => {
        window.location.reload()
      }, 2000)
    }
  }

  // UI Update Methods
  updateProgress(percentage) {
    if (this.hasProgressBarTarget) {
      const clampedPercentage = Math.min(100, Math.max(0, percentage))
      this.progressBarTarget.style.width = `${clampedPercentage}%`
      
      // Add visual feedback for milestone progress
      if (clampedPercentage >= 100) {
        this.progressBarTarget.classList.add('bg-green-500')
        this.progressBarTarget.classList.remove('bg-blue-600')
      }
    }

    if (this.hasProgressTextTarget) {
      this.progressTextTarget.textContent = `${Math.round(percentage)}%`
    }

    this.lastProgress = percentage
  }

  updateStatusMessage(message) {
    if (this.hasStatusMessageTarget) {
      this.statusMessageTarget.textContent = message
    }
  }

  updateCurrentStep(current, total) {
    if (this.hasCurrentStepTarget) {
      this.currentStepTarget.textContent = `${current}/${total}`
    }
  }

  calculateETA(currentPercentage) {
    if (!this.showEtaValue || this.progressHistory.length < 2) return

    const now = Date.now()
    const recentHistory = this.progressHistory.slice(-5) // Use last 5 data points
    
    if (recentHistory.length < 2) return

    // Calculate average progress rate
    const firstPoint = recentHistory[0]
    const lastPoint = recentHistory[recentHistory.length - 1]
    
    const progressDiff = lastPoint.percentage - firstPoint.percentage
    const timeDiff = lastPoint.timestamp - firstPoint.timestamp
    
    if (progressDiff <= 0 || timeDiff <= 0) return

    const progressRate = progressDiff / timeDiff // percentage per ms
    const remainingProgress = 100 - currentPercentage
    const estimatedRemainingTime = remainingProgress / progressRate

    this.updateETA(estimatedRemainingTime)
  }

  updateETA(remainingMs) {
    if (!this.hasEtaTarget) return

    const seconds = Math.round(remainingMs / 1000)
    
    if (seconds < 60) {
      this.etaTarget.textContent = `약 ${seconds}초 남음`
    } else if (seconds < 3600) {
      const minutes = Math.round(seconds / 60)
      this.etaTarget.textContent = `약 ${minutes}분 남음`
    } else {
      const hours = Math.round(seconds / 3600)
      this.etaTarget.textContent = `약 ${hours}시간 남음`
    }
  }

  hideETA() {
    if (this.hasEtaTarget) {
      this.etaTarget.textContent = ''
    }
  }

  showSuccessAnimation() {
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.classList.add('animate-pulse')
      setTimeout(() => {
        this.progressBarTarget.classList.remove('animate-pulse')
      }, 2000)
    }
  }

  showRetryOption() {
    // Create retry button if it doesn't exist
    const existingRetry = this.element.querySelector('.retry-button')
    if (existingRetry) return

    const retryButton = document.createElement('button')
    retryButton.className = 'retry-button mt-2 px-4 py-2 text-sm bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors'
    retryButton.textContent = '다시 시도'
    retryButton.addEventListener('click', () => {
      retryButton.remove()
      this.restart()
    })

    this.element.appendChild(retryButton)
  }

  // Public methods
  restart() {
    this.stopTracking()
    this.retryCount = 0
    this.progressHistory = []
    
    // Reset UI
    this.updateProgress(0)
    this.updateStatusMessage('다시 시작 중...')
    
    setTimeout(() => {
      this.startTracking()
    }, 1000)
  }

  cancel() {
    if (!this.jobIdValue) return

    fetch(`/api/v1/progress/cancel`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      },
      body: JSON.stringify({ job_id: this.jobIdValue })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.updateStatusMessage('작업을 취소하는 중...')
      }
    })
    .catch(error => {
      console.error('Failed to cancel job:', error)
    })
  }

  scheduleNextPoll() {
    this.pollTimeout = setTimeout(() => {
      this.pollProgress()
    }, this.pollIntervalValue)
  }

  dispatchProgressEvent(eventName, data) {
    const event = new CustomEvent(eventName, {
      detail: {
        jobId: this.jobIdValue,
        data: data,
        controller: this
      },
      bubbles: true
    })
    
    this.element.dispatchEvent(event)
  }
}

// Global progress tracking utilities
window.ProgressTracker = {
  start: function(element, jobId, options = {}) {
    const controller = this.getController(element)
    if (controller) {
      Object.assign(controller, options)
      controller.startTracking(jobId)
    }
  },

  stop: function(element) {
    const controller = this.getController(element)
    if (controller) {
      controller.stopTracking()
    }
  },

  getController: function(element) {
    if (typeof element === 'string') {
      element = document.querySelector(element)
    }
    
    if (!element) return null
    
    // Add controller if it doesn't exist
    if (!element.hasAttribute('data-controller') || !element.getAttribute('data-controller').includes('progress-tracker')) {
      const controllers = element.getAttribute('data-controller') || ''
      element.setAttribute('data-controller', `${controllers} progress-tracker`.trim())
    }
    
    return this.application?.getControllerForElementAndIdentifier(element, 'progress-tracker')
  }
}