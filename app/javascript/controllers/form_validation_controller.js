// Form Validation Stimulus Controller for real-time Korean feedback
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "error", "submit"]
  static values = { 
    validateOnBlur: { type: Boolean, default: true },
    validateOnInput: { type: Boolean, default: false },
    debounceDelay: { type: Number, default: 500 }
  }

  connect() {
    this.setupValidation()
    this.setupSubmitHandler()
  }

  setupValidation() {
    this.fieldTargets.forEach(field => {
      if (this.validateOnBlurValue) {
        field.addEventListener('blur', this.validateField.bind(this, field))
      }
      
      if (this.validateOnInputValue) {
        field.addEventListener('input', this.debounce(
          this.validateField.bind(this, field), 
          this.debounceDelayValue
        ))
      }
      
      // Clear errors on focus
      field.addEventListener('focus', this.clearFieldError.bind(this, field))
    })
  }

  setupSubmitHandler() {
    if (this.hasSubmitTarget) {
      this.submitTarget.addEventListener('click', this.validateForm.bind(this))
    } else {
      this.element.addEventListener('submit', this.validateForm.bind(this))
    }
  }

  validateField(field, event) {
    const fieldName = field.name || field.id
    const value = field.value.trim()
    const fieldType = field.type
    const required = field.hasAttribute('required')
    
    // Clear previous errors
    this.clearFieldError(field)
    
    // Validation rules
    const errors = []
    
    // Required field validation
    if (required && !value) {
      errors.push(this.getRequiredMessage(fieldName))
    }
    
    // Type-specific validation
    if (value) {
      switch (fieldType) {
        case 'email':
          if (!this.isValidEmail(value)) {
            errors.push('올바른 이메일 형식이 아닙니다')
          }
          break
        case 'url':
          if (!this.isValidUrl(value)) {
            errors.push('올바른 URL 형식이 아닙니다')
          }
          break
        case 'tel':
          if (!this.isValidPhone(value)) {
            errors.push('올바른 전화번호 형식이 아닙니다')
          }
          break
      }
      
      // Length validation
      const minLength = field.getAttribute('minlength')
      const maxLength = field.getAttribute('maxlength')
      
      if (minLength && value.length < parseInt(minLength)) {
        errors.push(`최소 ${minLength}자 이상 입력해주세요`)
      }
      
      if (maxLength && value.length > parseInt(maxLength)) {
        errors.push(`최대 ${maxLength}자까지 입력 가능합니다`)
      }
      
      // Custom validation patterns
      const pattern = field.getAttribute('pattern')
      if (pattern && !new RegExp(pattern).test(value)) {
        errors.push(this.getPatternMessage(fieldName))
      }
      
      // Content-specific validation
      if (fieldName === 'content' || field.classList.contains('content-field')) {
        errors.push(...this.validateContent(value))
      }
    }
    
    // Display errors or success
    if (errors.length > 0) {
      this.showFieldError(field, errors[0])
      return false
    } else if (value) {
      this.showFieldSuccess(field)
      return true
    }
    
    return true
  }

  validateForm(event) {
    let isValid = true
    const errors = []
    
    this.fieldTargets.forEach(field => {
      if (!this.validateField(field)) {
        isValid = false
      }
    })
    
    // Form-level validation
    if (isValid) {
      isValid = this.validateFormLogic()
    }
    
    if (!isValid && event) {
      event.preventDefault()
      this.showFormErrors(errors)
    }
    
    return isValid
  }

  validateFormLogic() {
    // Custom form-level validation logic
    const formType = this.element.dataset.formType
    
    switch (formType) {
      case 'text_note':
        return this.validateTextNoteForm()
      case 'sermon_automation':
        return this.validateSermonAutomationForm()
      default:
        return true
    }
  }

  validateTextNoteForm() {
    const contentField = this.element.querySelector('[name="text_note[content]"]')
    const titleField = this.element.querySelector('[name="text_note[title]"]')
    
    if (!contentField || !titleField) return true
    
    const content = contentField.value.trim()
    const title = titleField.value.trim()
    
    // Content validation
    if (content.length < 10) {
      this.showFieldError(contentField, '내용은 최소 10자 이상 입력해주세요')
      return false
    }
    
    if (content.length > 800) {
      this.showFieldError(contentField, '내용은 최대 800자까지 입력 가능합니다')
      return false
    }
    
    // Korean content detection
    if (!this.hasKoreanText(content)) {
      this.showFieldError(contentField, '한국어 내용을 입력해주세요')
      return false
    }
    
    return true
  }

  validateSermonAutomationForm() {
    const urlsField = this.element.querySelector('[name="sermon_urls"]')
    if (!urlsField) return true
    
    const urls = urlsField.value.trim().split(/\r?\n/).filter(url => url.trim())
    
    if (urls.length === 0) {
      this.showFieldError(urlsField, '최소 하나의 URL을 입력해주세요')
      return false
    }
    
    // Validate each URL
    for (const url of urls) {
      if (!this.isValidUrl(url.trim())) {
        this.showFieldError(urlsField, `올바르지 않은 URL: ${url}`)
        return false
      }
    }
    
    return true
  }

  validateContent(content) {
    const errors = []
    
    // Check for Korean text
    if (!this.hasKoreanText(content)) {
      errors.push('한국어 내용을 포함해야 합니다')
    }
    
    // Check for inappropriate content (basic)
    if (this.hasInappropriateContent(content)) {
      errors.push('부적절한 내용이 포함되어 있습니다')
    }
    
    // Check for minimum meaningful content
    if (content.length < 10) {
      errors.push('의미 있는 내용을 입력해주세요')
    }
    
    return errors
  }

  showFieldError(field, message) {
    this.clearFieldError(field)
    
    // Add error class to field
    field.classList.add('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
    field.classList.remove('border-green-300', 'focus:border-green-500', 'focus:ring-green-500')
    
    // Create error message element
    const errorElement = document.createElement('div')
    errorElement.className = 'mt-1 text-sm text-red-600 field-error'
    errorElement.textContent = message
    
    // Insert error message
    const container = field.closest('.form-group') || field.parentNode
    container.appendChild(errorElement)
    
    // Add error icon
    this.addFieldIcon(field, 'error')
  }

  showFieldSuccess(field) {
    this.clearFieldError(field)
    
    // Add success class to field
    field.classList.add('border-green-300', 'focus:border-green-500', 'focus:ring-green-500')
    field.classList.remove('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
    
    // Add success icon
    this.addFieldIcon(field, 'success')
  }

  clearFieldError(field) {
    // Remove error classes
    field.classList.remove('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
    field.classList.remove('border-green-300', 'focus:border-green-500', 'focus:ring-green-500')
    
    // Remove error messages
    const container = field.closest('.form-group') || field.parentNode
    const errorElements = container.querySelectorAll('.field-error')
    errorElements.forEach(el => el.remove())
    
    // Remove icons
    const iconElements = container.querySelectorAll('.field-icon')
    iconElements.forEach(el => el.remove())
  }

  addFieldIcon(field, type) {
    const container = field.closest('.form-group') || field.parentNode
    const existingIcon = container.querySelector('.field-icon')
    if (existingIcon) existingIcon.remove()
    
    const icon = document.createElement('div')
    icon.className = 'absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none field-icon'
    
    const svg = type === 'success' ? this.getSuccessIcon() : this.getErrorIcon()
    icon.innerHTML = svg
    
    // Position the icon
    if (field.parentNode.classList.contains('relative')) {
      field.parentNode.appendChild(icon)
    } else {
      const wrapper = document.createElement('div')
      wrapper.className = 'relative'
      field.parentNode.insertBefore(wrapper, field)
      wrapper.appendChild(field)
      wrapper.appendChild(icon)
    }
  }

  showFormErrors(errors) {
    // Use FlashMessages if available
    if (window.FlashMessages) {
      errors.forEach(error => {
        window.FlashMessages.error(error)
      })
    }
  }

  // Validation helper methods
  isValidEmail(email) {
    const pattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return pattern.test(email)
  }

  isValidUrl(url) {
    try {
      new URL(url)
      return true
    } catch {
      return false
    }
  }

  isValidPhone(phone) {
    const pattern = /^[\d\-\+\(\)\s]+$/
    return pattern.test(phone) && phone.length >= 10
  }

  hasKoreanText(text) {
    const koreanPattern = /[ㄱ-ㅎ|ㅏ-ㅣ|가-힣]/
    return koreanPattern.test(text)
  }

  hasInappropriateContent(content) {
    const inappropriateWords = ['스팸', '광고', '욕설'] // Basic list
    return inappropriateWords.some(word => content.includes(word))
  }

  getRequiredMessage(fieldName) {
    const messages = {
      title: '제목을 입력해주세요',
      content: '내용을 입력해주세요',
      email: '이메일을 입력해주세요',
      name: '이름을 입력해주세요',
      url: 'URL을 입력해주세요',
      sermon_urls: '설교 URL을 입력해주세요'
    }
    
    return messages[fieldName] || '필수 항목입니다'
  }

  getPatternMessage(fieldName) {
    const messages = {
      email: '올바른 이메일 형식으로 입력해주세요',
      url: '올바른 URL 형식으로 입력해주세요',
      phone: '올바른 전화번호 형식으로 입력해주세요'
    }
    
    return messages[fieldName] || '형식이 올바르지 않습니다'
  }

  getSuccessIcon() {
    return `
      <svg class="h-5 w-5 text-green-500" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
      </svg>
    `
  }

  getErrorIcon() {
    return `
      <svg class="h-5 w-5 text-red-500" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
      </svg>
    `
  }

  // Utility method for debouncing
  debounce(func, wait) {
    let timeout
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout)
        func(...args)
      }
      clearTimeout(timeout)
      timeout = setTimeout(later, wait)
    }
  }
}