// Lazy Load Stimulus Controller for images and components
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "component"]
  static values = { 
    threshold: { type: Number, default: 0.1 },
    rootMargin: { type: String, default: "50px 0px" },
    fadeIn: { type: Boolean, default: true },
    placeholder: { type: String, default: "" },
    errorPlaceholder: { type: String, default: "" }
  }

  connect() {
    this.setupIntersectionObserver()
    this.loadedCount = 0
    this.totalCount = this.imageTargets.length + this.componentTargets.length
    
    // Set up initial placeholders
    this.setupPlaceholders()
  }

  disconnect() {
    if (this.intersectionObserver) {
      this.intersectionObserver.disconnect()
    }
  }

  setupIntersectionObserver() {
    // Check for IntersectionObserver support
    if (!('IntersectionObserver' in window)) {
      this.loadAllImmediately()
      return
    }

    this.intersectionObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.loadElement(entry.target)
          this.intersectionObserver.unobserve(entry.target)
        }
      })
    }, {
      rootMargin: this.rootMarginValue,
      threshold: this.thresholdValue
    })

    // Observe all lazy loadable elements
    this.observeElements()
  }

  observeElements() {
    // Observe lazy images
    this.imageTargets.forEach(img => {
      if (!img.dataset.loaded) {
        this.intersectionObserver.observe(img)
      }
    })

    // Observe lazy components
    this.componentTargets.forEach(component => {
      if (!component.dataset.loaded) {
        this.intersectionObserver.observe(component)
      }
    })
  }

  setupPlaceholders() {
    this.imageTargets.forEach(img => {
      if (!img.dataset.loaded && !img.src) {
        this.setImagePlaceholder(img)
      }
    })

    this.componentTargets.forEach(component => {
      if (!component.dataset.loaded && component.innerHTML.trim() === '') {
        this.setComponentPlaceholder(component)
      }
    })
  }

  setImagePlaceholder(img) {
    // Create a lightweight placeholder
    const width = img.dataset.width || 300
    const height = img.dataset.height || 200
    
    // Use a data URL for a simple gray placeholder
    const placeholder = this.placeholderValue || 
      `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(this.generatePlaceholderSVG(width, height))}`
    
    img.src = placeholder
    img.classList.add('lazy-placeholder')
    
    if (this.fadeInValue) {
      img.style.opacity = '0.3'
      img.style.transition = 'opacity 0.3s ease-in-out'
    }
  }

  setComponentPlaceholder(component) {
    const placeholderType = component.dataset.placeholderType || 'default'
    component.innerHTML = this.getComponentPlaceholder(placeholderType)
    component.classList.add('lazy-placeholder')
  }

  generatePlaceholderSVG(width, height) {
    return `
      <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="#f3f4f6"/>
        <text x="50%" y="50%" font-family="Arial, sans-serif" font-size="14" 
              fill="#9ca3af" text-anchor="middle" dy=".3em">Loading...</text>
      </svg>
    `
  }

  getComponentPlaceholder(type) {
    const placeholders = {
      default: `
        <div class="animate-pulse bg-gray-200 rounded p-4">
          <div class="h-4 bg-gray-300 rounded w-3/4 mb-2"></div>
          <div class="h-4 bg-gray-300 rounded w-1/2"></div>
        </div>
      `,
      
      card: `
        <div class="animate-pulse">
          <div class="h-48 bg-gray-200 rounded-lg mb-4"></div>
          <div class="h-6 bg-gray-200 rounded w-3/4 mb-2"></div>
          <div class="h-4 bg-gray-200 rounded w-1/2"></div>
        </div>
      `,
      
      text: `
        <div class="animate-pulse space-y-2">
          <div class="h-4 bg-gray-200 rounded w-full"></div>
          <div class="h-4 bg-gray-200 rounded w-5/6"></div>
          <div class="h-4 bg-gray-200 rounded w-3/4"></div>
        </div>
      `,
      
      video: `
        <div class="animate-pulse bg-gray-200 rounded-lg flex items-center justify-center h-64">
          <svg class="w-16 h-16 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1m4 0h1m-6 4h1m4 0h1m6-8a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          </svg>
        </div>
      `
    }

    return placeholders[type] || placeholders.default
  }

  async loadElement(element) {
    if (element.dataset.loaded === 'true') return

    try {
      if (this.imageTargets.includes(element)) {
        await this.loadImage(element)
      } else if (this.componentTargets.includes(element)) {
        await this.loadComponent(element)
      }
      
      element.dataset.loaded = 'true'
      this.loadedCount++
      
      this.dispatchLoadEvent('lazy:loaded', {
        element,
        progress: (this.loadedCount / this.totalCount) * 100
      })
      
      if (this.loadedCount === this.totalCount) {
        this.dispatchLoadEvent('lazy:complete')
      }
    } catch (error) {
      this.handleLoadError(element, error)
    }
  }

  async loadImage(img) {
    const actualSrc = img.dataset.src || img.dataset.lazySrc
    if (!actualSrc) return

    return new Promise((resolve, reject) => {
      const tempImg = new Image()
      
      tempImg.onload = () => {
        // Replace placeholder with actual image
        img.src = actualSrc
        img.classList.remove('lazy-placeholder')
        
        if (this.fadeInValue) {
          img.style.opacity = '1'
        }
        
        // Set up responsive attributes if available
        if (img.dataset.srcset) {
          img.srcset = img.dataset.srcset
        }
        
        if (img.dataset.sizes) {
          img.sizes = img.dataset.sizes
        }
        
        resolve()
      }
      
      tempImg.onerror = () => {
        reject(new Error(`Failed to load image: ${actualSrc}`))
      }
      
      // Start loading
      tempImg.src = actualSrc
    })
  }

  async loadComponent(component) {
    const url = component.dataset.src || component.dataset.lazyUrl
    if (!url) return

    try {
      const response = await fetch(url, {
        headers: {
          'Accept': 'text/html, application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      const contentType = response.headers.get('content-type')
      
      if (contentType && contentType.includes('application/json')) {
        const data = await response.json()
        if (data.html) {
          component.innerHTML = data.html
        } else {
          throw new Error('No HTML content in JSON response')
        }
      } else {
        const html = await response.text()
        component.innerHTML = html
      }

      component.classList.remove('lazy-placeholder')
      
      // Initialize any Stimulus controllers in the loaded content
      if (this.application) {
        this.application.start()
      }
      
    } catch (error) {
      throw new Error(`Failed to load component from ${url}: ${error.message}`)
    }
  }

  handleLoadError(element, error) {
    console.error('Lazy load error:', error)
    
    if (this.imageTargets.includes(element)) {
      this.setImageError(element)
    } else {
      this.setComponentError(element)
    }
    
    this.dispatchLoadEvent('lazy:error', { element, error: error.message })
  }

  setImageError(img) {
    const errorPlaceholder = this.errorPlaceholderValue ||
      `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(this.generateErrorSVG())}`
    
    img.src = errorPlaceholder
    img.classList.add('lazy-error')
    img.classList.remove('lazy-placeholder')
  }

  setComponentError(component) {
    component.innerHTML = `
      <div class="lazy-error p-4 bg-red-50 border border-red-200 rounded text-center">
        <svg class="w-8 h-8 text-red-400 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"></path>
        </svg>
        <p class="text-sm text-red-600">콘텐츠를 불러올 수 없습니다</p>
      </div>
    `
    component.classList.remove('lazy-placeholder')
  }

  generateErrorSVG() {
    return `
      <svg width="300" height="200" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="#fee2e2"/>
        <text x="50%" y="50%" font-family="Arial, sans-serif" font-size="14" 
              fill="#dc2626" text-anchor="middle" dy=".3em">이미지를 불러올 수 없습니다</text>
      </svg>
    `
  }

  // Public methods
  loadAll() {
    const allElements = [...this.imageTargets, ...this.componentTargets]
    allElements.forEach(element => {
      if (!element.dataset.loaded) {
        this.loadElement(element)
      }
    })
  }

  loadAllImmediately() {
    // Fallback for browsers without IntersectionObserver
    this.loadAll()
  }

  refresh() {
    // Reset all elements and reload
    const allElements = [...this.imageTargets, ...this.componentTargets]
    allElements.forEach(element => {
      element.dataset.loaded = 'false'
      if (this.imageTargets.includes(element)) {
        this.setImagePlaceholder(element)
      } else {
        this.setComponentPlaceholder(element)
      }
    })
    
    this.loadedCount = 0
    this.observeElements()
  }

  // Utility methods
  getLoadProgress() {
    return {
      loaded: this.loadedCount,
      total: this.totalCount,
      percentage: this.totalCount > 0 ? (this.loadedCount / this.totalCount) * 100 : 100
    }
  }

  isCompletelyLoaded() {
    return this.loadedCount === this.totalCount
  }

  dispatchLoadEvent(eventName, detail = {}) {
    const event = new CustomEvent(eventName, {
      detail: {
        controller: this,
        progress: this.getLoadProgress(),
        ...detail
      },
      bubbles: true
    })
    
    this.element.dispatchEvent(event)
  }
}

// Global lazy loading utilities
window.LazyLoad = {
  // Lazy load specific element
  load: function(element) {
    const controller = this.getController(element.closest('[data-controller*="lazy-load"]'))
    if (controller) {
      controller.loadElement(element)
    }
  },

  // Load all lazy elements in container
  loadAll: function(container = document) {
    const lazyContainers = container.querySelectorAll('[data-controller*="lazy-load"]')
    lazyContainers.forEach(container => {
      const controller = this.getController(container)
      if (controller) {
        controller.loadAll()
      }
    })
  },

  // Get loading progress for container
  getProgress: function(container) {
    const controller = this.getController(container)
    return controller ? controller.getLoadProgress() : { loaded: 0, total: 0, percentage: 100 }
  },

  getController: function(element) {
    if (typeof element === 'string') {
      element = document.querySelector(element)
    }
    
    if (!element) return null
    
    return this.application?.getControllerForElementAndIdentifier(element, 'lazy-load')
  }
}