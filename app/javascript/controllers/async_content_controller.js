// Async Content Loading Stimulus Controller
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    url: String,
    method: { type: String, default: 'GET' },
    autoLoad: { type: Boolean, default: true },
    loadOnVisible: { type: Boolean, default: false },
    retryAttempts: { type: Number, default: 3 },
    retryDelay: { type: Number, default: 1000 },
    cache: { type: Boolean, default: true },
    fallbackContent: String
  }

  connect() {
    this.isLoaded = false
    this.isLoading = false
    this.retryCount = 0
    this.intersectionObserver = null
    
    if (this.autoLoadValue) {
      if (this.loadOnVisibleValue) {
        this.setupIntersectionObserver()
      } else {
        this.loadContent()
      }
    }
  }

  disconnect() {
    if (this.intersectionObserver) {
      this.intersectionObserver.disconnect()
    }
  }

  setupIntersectionObserver() {
    if (!('IntersectionObserver' in window)) {
      // Fallback for browsers without IntersectionObserver
      this.loadContent()
      return
    }

    this.intersectionObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting && !this.isLoaded && !this.isLoading) {
          this.loadContent()
          this.intersectionObserver.disconnect()
        }
      })
    }, {
      rootMargin: '50px 0px', // Start loading 50px before element is visible
      threshold: 0.1
    })

    this.intersectionObserver.observe(this.element)
  }

  async loadContent() {
    if (this.isLoaded || this.isLoading || !this.urlValue) return

    this.isLoading = true
    this.showLoadingState()

    // Check cache first
    if (this.cacheValue) {
      const cachedContent = this.getCachedContent()
      if (cachedContent) {
        this.displayContent(cachedContent)
        return
      }
    }

    try {
      const response = await this.fetchContent()
      
      if (response.ok) {
        const contentType = response.headers.get('content-type')
        
        if (contentType && contentType.includes('application/json')) {
          const data = await response.json()
          this.handleJsonResponse(data)
        } else {
          const html = await response.text()
          this.displayContent(html)
          
          // Cache successful response
          if (this.cacheValue) {
            this.setCachedContent(html)
          }
        }
        
        this.retryCount = 0
        this.dispatchContentEvent('async:loaded')
      } else {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }
    } catch (error) {
      this.handleLoadError(error)
    }
  }

  async fetchContent() {
    const fetchOptions = {
      method: this.methodValue,
      headers: {
        'Accept': 'text/html, application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    }

    // Add CSRF token for non-GET requests
    if (this.methodValue !== 'GET') {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
      if (csrfToken) {
        fetchOptions.headers['X-CSRF-Token'] = csrfToken
      }
    }

    return fetch(this.urlValue, fetchOptions)
  }

  handleJsonResponse(data) {
    if (data.html) {
      this.displayContent(data.html)
    } else if (data.redirect_url) {
      window.location.href = data.redirect_url
    } else if (data.error) {
      this.showErrorState(data.error)
    } else {
      // Try to render JSON data as content
      this.displayContent(this.formatJsonAsHtml(data))
    }
  }

  displayContent(html) {
    this.element.innerHTML = html
    this.isLoaded = true
    this.isLoading = false
    
    // Initialize any Stimulus controllers in the new content
    if (this.application) {
      this.application.start()
    }
    
    // Trigger any lazy-loaded images
    this.triggerLazyImages()
    
    this.dispatchContentEvent('async:displayed', { html })
  }

  showLoadingState() {
    const loadingHtml = `
      <div class="async-loading flex items-center justify-center p-8">
        <div class="animate-spin rounded-full h-8 w-8 border-4 border-blue-200 border-t-blue-600"></div>
        <span class="ml-3 text-gray-600">로딩 중...</span>
      </div>
    `
    this.element.innerHTML = loadingHtml
    this.dispatchContentEvent('async:loading')
  }

  showErrorState(errorMessage) {
    const errorHtml = `
      <div class="async-error p-6 bg-red-50 border border-red-200 rounded-lg">
        <div class="flex items-center mb-3">
          <svg class="w-5 h-5 text-red-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"></path>
          </svg>
          <span class="text-sm font-medium text-red-800">콘텐츠 로딩 실패</span>
        </div>
        <p class="text-sm text-red-700 mb-3">${errorMessage}</p>
        <button class="text-sm bg-red-600 text-white px-3 py-1 rounded hover:bg-red-700 transition-colors"
                data-action="click->async-content#retry">
          다시 시도
        </button>
      </div>
    `
    
    this.element.innerHTML = errorHtml
    this.isLoading = false
    this.dispatchContentEvent('async:error', { error: errorMessage })
  }

  showFallbackContent() {
    if (this.fallbackContentValue) {
      this.element.innerHTML = this.fallbackContentValue
    } else {
      this.element.innerHTML = `
        <div class="async-fallback p-6 bg-gray-50 border border-gray-200 rounded-lg text-center">
          <p class="text-gray-600">콘텐츠를 불러올 수 없습니다</p>
        </div>
      `
    }
  }

  handleLoadError(error) {
    console.error('Async content load error:', error)
    
    this.retryCount++
    
    if (this.retryCount <= this.retryAttemptsValue) {
      const delay = this.retryDelayValue * Math.pow(2, this.retryCount - 1) // Exponential backoff
      
      setTimeout(() => {
        this.loadContent()
      }, delay)
    } else {
      this.showFallbackContent()
    }
  }

  // Public methods
  retry() {
    this.retryCount = 0
    this.isLoaded = false
    this.isLoading = false
    this.loadContent()
  }

  refresh() {
    this.clearCache()
    this.retry()
  }

  // Cache management
  getCachedContent() {
    if (!this.cacheValue) return null
    
    try {
      const cacheKey = this.getCacheKey()
      const cached = localStorage.getItem(cacheKey)
      
      if (cached) {
        const data = JSON.parse(cached)
        const now = Date.now()
        
        // Check if cache is still valid (default 5 minutes)
        if (now - data.timestamp < 5 * 60 * 1000) {
          return data.content
        } else {
          localStorage.removeItem(cacheKey)
        }
      }
    } catch (error) {
      console.warn('Cache read error:', error)
    }
    
    return null
  }

  setCachedContent(content) {
    if (!this.cacheValue) return
    
    try {
      const cacheKey = this.getCacheKey()
      const data = {
        content: content,
        timestamp: Date.now()
      }
      
      localStorage.setItem(cacheKey, JSON.stringify(data))
    } catch (error) {
      console.warn('Cache write error:', error)
    }
  }

  clearCache() {
    try {
      const cacheKey = this.getCacheKey()
      localStorage.removeItem(cacheKey)
    } catch (error) {
      console.warn('Cache clear error:', error)
    }
  }

  getCacheKey() {
    // Create a cache key based on URL and current user
    const url = new URL(this.urlValue, window.location.origin)
    return `async_content_${btoa(url.pathname + url.search)}`
  }

  triggerLazyImages() {
    const lazyImages = this.element.querySelectorAll('img[loading="lazy"]')
    
    if ('IntersectionObserver' in window) {
      const imageObserver = new IntersectionObserver((entries, observer) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            const img = entry.target
            if (img.dataset.src) {
              img.src = img.dataset.src
              img.removeAttribute('data-src')
            }
            observer.unobserve(img)
          }
        })
      })
      
      lazyImages.forEach(img => imageObserver.observe(img))
    } else {
      // Fallback: load all images immediately
      lazyImages.forEach(img => {
        if (img.dataset.src) {
          img.src = img.dataset.src
          img.removeAttribute('data-src')
        }
      })
    }
  }

  formatJsonAsHtml(data) {
    // Simple JSON to HTML formatter
    if (typeof data === 'object') {
      let html = '<div class="json-content">'
      
      for (const [key, value] of Object.entries(data)) {
        html += `<div class="json-item mb-2">
          <strong class="json-key">${key}:</strong>
          <span class="json-value ml-2">${this.formatValue(value)}</span>
        </div>`
      }
      
      html += '</div>'
      return html
    }
    
    return `<div class="json-simple">${data}</div>`
  }

  formatValue(value) {
    if (typeof value === 'object') {
      return JSON.stringify(value, null, 2)
    }
    return String(value)
  }

  dispatchContentEvent(eventName, detail = {}) {
    const event = new CustomEvent(eventName, {
      detail: {
        url: this.urlValue,
        element: this.element,
        ...detail
      },
      bubbles: true
    })
    
    this.element.dispatchEvent(event)
  }
}

// Global async content utilities
window.AsyncContent = {
  load: function(element, url, options = {}) {
    const controller = this.getController(element)
    if (controller) {
      controller.urlValue = url
      Object.assign(controller, options)
      controller.loadContent()
    }
  },

  refresh: function(element) {
    const controller = this.getController(element)
    if (controller) {
      controller.refresh()
    }
  },

  getController: function(element) {
    if (typeof element === 'string') {
      element = document.querySelector(element)
    }
    
    if (!element) return null
    
    // Add controller if it doesn't exist
    if (!element.hasAttribute('data-controller') || !element.getAttribute('data-controller').includes('async-content')) {
      const controllers = element.getAttribute('data-controller') || ''
      element.setAttribute('data-controller', `${controllers} async-content`.trim())
    }
    
    return this.application?.getControllerForElementAndIdentifier(element, 'async-content')
  }
}