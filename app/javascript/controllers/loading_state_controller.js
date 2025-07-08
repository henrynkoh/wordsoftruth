// Loading State Stimulus Controller for comprehensive loading management
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["spinner", "content", "skeleton", "progress", "message"]
  static values = { 
    type: { type: String, default: "spinner" }, // spinner, skeleton, progress, custom
    message: { type: String, default: "로딩 중..." },
    autoHide: { type: Boolean, default: true },
    showProgress: { type: Boolean, default: false },
    minDuration: { type: Number, default: 500 } // Minimum loading time for UX
  }

  connect() {
    this.startTime = Date.now()
    this.isLoading = false
    this.setupLoadingState()
  }

  disconnect() {
    this.clearTimeouts()
  }

  setupLoadingState() {
    // Initialize loading UI based on type
    this.createLoadingElements()
    
    // Listen for loading events
    this.element.addEventListener('loading:start', this.handleLoadingStart.bind(this))
    this.element.addEventListener('loading:progress', this.handleLoadingProgress.bind(this))
    this.element.addEventListener('loading:complete', this.handleLoadingComplete.bind(this))
    this.element.addEventListener('loading:error', this.handleLoadingError.bind(this))
    
    // Auto-start loading if data attribute is present
    if (this.element.dataset.autoStart === 'true') {
      this.startLoading()
    }
  }

  createLoadingElements() {
    switch (this.typeValue) {
      case 'spinner':
        this.createSpinner()
        break
      case 'skeleton':
        this.createSkeleton()
        break
      case 'progress':
        this.createProgressBar()
        break
      case 'pulse':
        this.createPulseAnimation()
        break
      default:
        this.createSpinner()
    }
  }

  createSpinner() {
    if (this.hasSpinnerTarget) return

    const spinner = document.createElement('div')
    spinner.className = 'loading-spinner flex items-center justify-center p-8'
    spinner.innerHTML = `
      <div class="relative">
        <div class="animate-spin rounded-full h-12 w-12 border-4 border-blue-200 border-t-blue-600"></div>
        <div class="absolute inset-0 flex items-center justify-center">
          <div class="w-3 h-3 bg-blue-600 rounded-full animate-pulse"></div>
        </div>
      </div>
      <div class="ml-4 text-gray-600 font-medium">${this.messageValue}</div>
    `
    
    this.element.appendChild(spinner)
  }

  createSkeleton() {
    if (this.hasSkeletonTarget) return

    const skeleton = document.createElement('div')
    skeleton.className = 'loading-skeleton space-y-4 p-4'
    
    // Determine skeleton type based on content
    const skeletonType = this.element.dataset.skeletonType || 'default'
    skeleton.innerHTML = this.getSkeletonHTML(skeletonType)
    
    this.element.appendChild(skeleton)
  }

  createProgressBar() {
    if (this.hasProgressTarget) return

    const progressContainer = document.createElement('div')
    progressContainer.className = 'loading-progress'
    progressContainer.innerHTML = `
      <div class="mb-2 flex justify-between items-center">
        <span class="text-sm font-medium text-gray-700">${this.messageValue}</span>
        <span class="text-sm text-gray-500 progress-percentage">0%</span>
      </div>
      <div class="w-full bg-gray-200 rounded-full h-2.5">
        <div class="bg-blue-600 h-2.5 rounded-full transition-all duration-300 ease-out progress-bar" style="width: 0%"></div>
      </div>
      <div class="mt-2 text-xs text-gray-500 progress-message">처리 중...</div>
    `
    
    this.element.appendChild(progressContainer)
  }

  createPulseAnimation() {
    const content = this.hasContentTarget ? this.contentTarget : this.element
    content.classList.add('animate-pulse', 'bg-gray-100', 'rounded')
  }

  getSkeletonHTML(type) {
    const skeletonTemplates = {
      default: `
        <div class="animate-pulse">
          <div class="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
          <div class="h-4 bg-gray-200 rounded w-1/2 mb-4"></div>
          <div class="h-20 bg-gray-200 rounded mb-4"></div>
          <div class="h-4 bg-gray-200 rounded w-2/3"></div>
        </div>
      `,
      
      card: `
        <div class="animate-pulse">
          <div class="h-48 bg-gray-200 rounded-lg mb-4"></div>
          <div class="h-6 bg-gray-200 rounded w-3/4 mb-2"></div>
          <div class="h-4 bg-gray-200 rounded w-1/2 mb-2"></div>
          <div class="h-4 bg-gray-200 rounded w-2/3"></div>
        </div>
      `,
      
      list: `
        <div class="animate-pulse space-y-3">
          ${Array(5).fill().map(() => `
            <div class="flex items-center space-x-3">
              <div class="h-10 w-10 bg-gray-200 rounded-full"></div>
              <div class="flex-1">
                <div class="h-4 bg-gray-200 rounded w-3/4 mb-1"></div>
                <div class="h-3 bg-gray-200 rounded w-1/2"></div>
              </div>
            </div>
          `).join('')}
        </div>
      `,
      
      text_note: `
        <div class="animate-pulse">
          <div class="flex items-center mb-4">
            <div class="h-8 w-8 bg-gray-200 rounded-full mr-3"></div>
            <div class="h-5 bg-gray-200 rounded w-1/3"></div>
          </div>
          <div class="space-y-2 mb-4">
            <div class="h-4 bg-gray-200 rounded w-full"></div>
            <div class="h-4 bg-gray-200 rounded w-5/6"></div>
            <div class="h-4 bg-gray-200 rounded w-3/4"></div>
          </div>
          <div class="flex space-x-2">
            <div class="h-8 bg-gray-200 rounded w-20"></div>
            <div class="h-8 bg-gray-200 rounded w-24"></div>
          </div>
        </div>
      `,

      video_generation: `
        <div class="animate-pulse">
          <div class="h-64 bg-gray-200 rounded-lg mb-4 flex items-center justify-center">
            <div class="text-gray-400 text-lg">🎬</div>
          </div>
          <div class="h-6 bg-gray-200 rounded w-2/3 mb-2"></div>
          <div class="h-4 bg-gray-200 rounded w-1/2 mb-4"></div>
          <div class="flex space-x-2">
            <div class="h-10 bg-gray-200 rounded w-24"></div>
            <div class="h-10 bg-gray-200 rounded w-32"></div>
          </div>
        </div>
      `
    }

    return skeletonTemplates[type] || skeletonTemplates.default
  }

  // Event handlers
  handleLoadingStart(event) {
    const { message, type, showProgress } = event.detail || {}
    
    if (message) this.messageValue = message
    if (type) this.typeValue = type
    if (showProgress !== undefined) this.showProgressValue = showProgress
    
    this.startLoading()
  }

  handleLoadingProgress(event) {
    const { percentage, message, step, total } = event.detail || {}
    
    this.updateProgress(percentage, message, step, total)
  }

  handleLoadingComplete(event) {
    const { message, delay } = event.detail || {}
    
    this.completeLoading(message, delay)
  }

  handleLoadingError(event) {
    const { error, message } = event.detail || {}
    
    this.showError(error || message || '오류가 발생했습니다')
  }

  // Public methods
  startLoading(options = {}) {
    if (this.isLoading) return

    this.isLoading = true
    this.startTime = Date.now()
    
    // Update message if provided
    if (options.message) {
      this.messageValue = options.message
      this.updateMessage(options.message)
    }
    
    // Show loading state
    this.showLoadingState()
    
    // Hide content if exists
    if (this.hasContentTarget) {
      this.contentTarget.classList.add('hidden')
    }
    
    // Dispatch loading start event
    this.dispatchLoadingEvent('loading:started', {
      timestamp: this.startTime,
      type: this.typeValue
    })
  }

  completeLoading(successMessage = '완료되었습니다', delay = 0) {
    if (!this.isLoading) return

    const elapsed = Date.now() - this.startTime
    const remainingMinTime = Math.max(0, this.minDurationValue - elapsed)
    const totalDelay = delay + remainingMinTime

    setTimeout(() => {
      this.hideLoadingState()
      
      // Show content
      if (this.hasContentTarget) {
        this.contentTarget.classList.remove('hidden')
      }
      
      // Show success message if provided
      if (successMessage && window.FlashMessages) {
        window.FlashMessages.success(successMessage)
      }
      
      this.isLoading = false
      
      // Dispatch completion event
      this.dispatchLoadingEvent('loading:finished', {
        duration: Date.now() - this.startTime,
        message: successMessage
      })
    }, totalDelay)
  }

  updateProgress(percentage, message, step, total) {
    const progressBar = this.element.querySelector('.progress-bar')
    const progressPercentage = this.element.querySelector('.progress-percentage')
    const progressMessage = this.element.querySelector('.progress-message')
    
    if (progressBar && percentage !== undefined) {
      progressBar.style.width = `${Math.min(100, Math.max(0, percentage))}%`
    }
    
    if (progressPercentage && percentage !== undefined) {
      progressPercentage.textContent = `${Math.round(percentage)}%`
    }
    
    if (progressMessage) {
      if (message) {
        progressMessage.textContent = message
      } else if (step !== undefined && total !== undefined) {
        progressMessage.textContent = `${step}/${total} 단계 처리 중...`
      }
    }
    
    // Dispatch progress event
    this.dispatchLoadingEvent('loading:progress_updated', {
      percentage,
      message,
      step,
      total
    })
  }

  updateMessage(message) {
    const messageElements = this.element.querySelectorAll('.loading-message, .progress-message')
    messageElements.forEach(el => {
      if (el) el.textContent = message
    })
  }

  showError(errorMessage) {
    this.hideLoadingState()
    
    // Create error state
    const errorElement = document.createElement('div')
    errorElement.className = 'loading-error flex items-center justify-center p-8 text-red-600'
    errorElement.innerHTML = `
      <svg class="w-6 h-6 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"></path>
      </svg>
      <span>${errorMessage}</span>
    `
    
    this.element.appendChild(errorElement)
    
    // Auto-remove error after 5 seconds
    setTimeout(() => {
      if (errorElement.parentNode) {
        errorElement.remove()
      }
    }, 5000)
    
    this.isLoading = false
  }

  retry() {
    this.clearLoadingState()
    
    // Dispatch retry event
    this.dispatchLoadingEvent('loading:retry', {
      timestamp: Date.now()
    })
  }

  reset() {
    this.clearLoadingState()
    this.isLoading = false
    
    if (this.hasContentTarget) {
      this.contentTarget.classList.remove('hidden')
    }
  }

  // Helper methods
  showLoadingState() {
    const loadingElements = this.element.querySelectorAll('.loading-spinner, .loading-skeleton, .loading-progress')
    loadingElements.forEach(el => el.classList.remove('hidden'))
  }

  hideLoadingState() {
    const loadingElements = this.element.querySelectorAll('.loading-spinner, .loading-skeleton, .loading-progress')
    loadingElements.forEach(el => el.classList.add('hidden'))
  }

  clearLoadingState() {
    const loadingElements = this.element.querySelectorAll('.loading-spinner, .loading-skeleton, .loading-progress, .loading-error')
    loadingElements.forEach(el => el.remove())
    
    // Remove pulse animation
    this.element.classList.remove('animate-pulse', 'bg-gray-100', 'rounded')
  }

  clearTimeouts() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  dispatchLoadingEvent(eventName, detail = {}) {
    const event = new CustomEvent(eventName, {
      detail: {
        controller: this,
        loadingType: this.typeValue,
        ...detail
      },
      bubbles: true
    })
    
    this.element.dispatchEvent(event)
  }
}

// Global loading utilities
window.LoadingStates = {
  // Show loading state on any element
  show: function(element, options = {}) {
    const controller = this.getController(element)
    if (controller) {
      controller.startLoading(options)
    }
  },

  // Hide loading state
  hide: function(element, message = null) {
    const controller = this.getController(element)
    if (controller) {
      controller.completeLoading(message)
    }
  },

  // Update progress
  progress: function(element, percentage, message = null) {
    const controller = this.getController(element)
    if (controller) {
      controller.updateProgress(percentage, message)
    }
  },

  // Show error
  error: function(element, errorMessage) {
    const controller = this.getController(element)
    if (controller) {
      controller.showError(errorMessage)
    }
  },

  // Get or create controller for element
  getController: function(element) {
    if (typeof element === 'string') {
      element = document.querySelector(element)
    }
    
    if (!element) return null
    
    // Add controller if it doesn't exist
    if (!element.hasAttribute('data-controller') || !element.getAttribute('data-controller').includes('loading-state')) {
      const controllers = element.getAttribute('data-controller') || ''
      element.setAttribute('data-controller', `${controllers} loading-state`.trim())
    }
    
    return this.application?.getControllerForElementAndIdentifier(element, 'loading-state')
  }
}