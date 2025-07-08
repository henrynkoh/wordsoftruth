// Flash Messages Stimulus Controller for enhanced user feedback
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]
  static values = { 
    autoDismiss: Boolean,
    dismissDelay: { type: Number, default: 5000 }
  }

  connect() {
    this.setupAutoHide()
    this.setupAnimations()
  }

  disconnect() {
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
    }
  }

  setupAutoHide() {
    // Auto-dismiss messages except for errors
    this.element.querySelectorAll('[data-flash-type]').forEach(message => {
      const flashType = message.dataset.flashType
      const autoDismiss = message.dataset.autoDismiss !== 'false'
      const dismissDelay = parseInt(message.dataset.dismissDelay) || this.dismissDelayValue
      
      if (autoDismiss && flashType !== 'error') {
        setTimeout(() => {
          this.dismissMessage(message)
        }, dismissDelay)
      }
    })
  }

  setupAnimations() {
    // Animate messages in
    this.element.querySelectorAll('.flash-message').forEach((message, index) => {
      message.style.transform = 'translateX(100%)'
      message.style.opacity = '0'
      
      setTimeout(() => {
        message.style.transition = 'all 0.3s ease-out'
        message.style.transform = 'translateX(0)'
        message.style.opacity = '1'
      }, index * 100)
    })
  }

  dismiss(event) {
    const message = event.target.closest('.flash-message')
    if (message) {
      this.dismissMessage(message)
    }
  }

  dismissMessage(message) {
    // Animate out
    message.style.transition = 'all 0.3s ease-in'
    message.style.transform = 'translateX(100%)'
    message.style.opacity = '0'
    
    // Remove from DOM after animation
    setTimeout(() => {
      if (message.parentNode) {
        message.remove()
      }
      
      // Remove container if no more messages
      if (this.element.children.length === 0) {
        this.element.remove()
      }
    }, 300)
  }

  dismissAll() {
    this.element.querySelectorAll('.flash-message').forEach(message => {
      this.dismissMessage(message)
    })
  }

  // Public method to add new flash messages dynamically
  addMessage(type, message, options = {}) {
    const messageConfig = this.getMessageConfig(type)
    const messageElement = this.createMessageElement(type, message, messageConfig, options)
    
    this.element.appendChild(messageElement)
    this.animateIn(messageElement)
    
    // Auto-dismiss if configured
    if (options.autoDismiss !== false && type !== 'error') {
      const delay = options.dismissDelay || this.dismissDelayValue
      setTimeout(() => {
        this.dismissMessage(messageElement)
      }, delay)
    }
  }

  createMessageElement(type, message, config, options) {
    const div = document.createElement('div')
    div.className = `flash-message border rounded-lg p-4 shadow-lg ${config.class}`
    div.dataset.flashType = type
    
    div.innerHTML = `
      <div class="flex items-start">
        ${this.createIcon(config)}
        <div class="ml-3 flex-1">
          <div class="text-sm font-medium">
            ${options.showLabel !== false ? `<span class="font-semibold">${config.label}: </span>` : ''}
            ${message}
          </div>
        </div>
        <div class="ml-4 flex-shrink-0">
          <button class="inline-flex text-gray-400 hover:text-gray-600 focus:outline-none"
                  data-action="click->flash-messages#dismiss">
            <span class="sr-only">닫기</span>
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>
      </div>
    `
    
    return div
  }

  createIcon(config) {
    const iconPaths = {
      'check-circle': "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z",
      'exclamation-triangle': "M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z",
      'x-circle': "M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z",
      'information-circle': "M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
    }
    
    const path = iconPaths[config.icon] || iconPaths['information-circle']
    
    return `
      <div class="flex-shrink-0">
        <svg class="w-5 h-5 ${config.iconClass}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="${path}"></path>
        </svg>
      </div>
    `
  }

  getMessageConfig(type) {
    const configs = {
      success: { 
        label: '성공', 
        icon: 'check-circle', 
        class: 'bg-green-50 border-green-200 text-green-800',
        iconClass: 'text-green-400'
      },
      warning: { 
        label: '경고', 
        icon: 'exclamation-triangle', 
        class: 'bg-yellow-50 border-yellow-200 text-yellow-800',
        iconClass: 'text-yellow-400'
      },
      error: { 
        label: '오류', 
        icon: 'x-circle', 
        class: 'bg-red-50 border-red-200 text-red-800',
        iconClass: 'text-red-400'
      },
      info: { 
        label: '정보', 
        icon: 'information-circle', 
        class: 'bg-blue-50 border-blue-200 text-blue-800',
        iconClass: 'text-blue-400'
      }
    }
    
    return configs[type] || configs.info
  }

  animateIn(element) {
    element.style.transform = 'translateX(100%)'
    element.style.opacity = '0'
    
    setTimeout(() => {
      element.style.transition = 'all 0.3s ease-out'
      element.style.transform = 'translateX(0)'
      element.style.opacity = '1'
    }, 10)
  }
}

// Export for use in other JavaScript modules
window.FlashMessages = {
  show: function(type, message, options = {}) {
    const container = document.querySelector('[data-controller="flash-messages"]') || 
                    this.createContainer()
    
    const controller = this.application.getControllerForElementAndIdentifier(container, 'flash-messages')
    if (controller) {
      controller.addMessage(type, message, options)
    }
  },

  createContainer: function() {
    const container = document.createElement('div')
    container.className = 'flash-messages-container fixed top-4 right-4 z-50 space-y-2 max-w-md'
    container.setAttribute('data-controller', 'flash-messages')
    document.body.appendChild(container)
    return container
  },

  success: function(message, options = {}) {
    this.show('success', message, options)
  },

  error: function(message, options = {}) {
    this.show('error', message, { autoDismiss: false, ...options })
  },

  warning: function(message, options = {}) {
    this.show('warning', message, options)
  },

  info: function(message, options = {}) {
    this.show('info', message, options)
  }
}