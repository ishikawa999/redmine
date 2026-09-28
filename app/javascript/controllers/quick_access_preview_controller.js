import { Controller } from "@hotwired/stimulus"

// Grace period so that moving the pointer diagonally towards the submenu
// does not close it
const CLOSE_DELAY_MS = 250

// Loads the quick access submenu of the account menu on first open
export default class extends Controller {
  static targets = ["preview"]
  static values = {
    url: String,
    loadingText: String,
    errorText: String
  }

  connect() {
    this.state = "idle"
    this.cachedHTML = null
    this.abortController = null
    this.closeTimeout = null

    this.open = this.open.bind(this)
    this.closeWhenOutside = this.closeWhenOutside.bind(this)
    this.closeOnEscape = this.closeOnEscape.bind(this)
    this.invalidate = this.invalidate.bind(this)

    this.element.addEventListener("pointerenter", this.open)
    this.element.addEventListener("pointerleave", this.closeWhenOutside)
    this.element.addEventListener("focusin", this.open)
    this.element.addEventListener("focusout", this.closeWhenOutside)
    document.addEventListener("keydown", this.closeOnEscape)
    document.addEventListener("quick-access-preview:invalidate", this.invalidate)

    this.renderState("idle")
  }

  disconnect() {
    this.element.removeEventListener("pointerenter", this.open)
    this.element.removeEventListener("pointerleave", this.closeWhenOutside)
    this.element.removeEventListener("focusin", this.open)
    this.element.removeEventListener("focusout", this.closeWhenOutside)
    document.removeEventListener("keydown", this.closeOnEscape)
    document.removeEventListener("quick-access-preview:invalidate", this.invalidate)
    this.cancelScheduledClose()
    this.abortRequest()
  }

  open() {
    if (this.mobileNavigationVisible()) return

    this.cancelScheduledClose()
    this.previewTarget.classList.add("is-open")

    if (this.cachedHTML !== null) {
      // Keep existing links intact when focus moves inside the preview.
      this.renderState(this.cachedHTMLHasItems() ? "loaded" : "empty")
    } else if (this.state === "idle" || this.state === "error") {
      this.load()
    }
  }

  closeWhenOutside(event) {
    if (event.relatedTarget && this.element.contains(event.relatedTarget)) return

    this.scheduleClose()
  }

  closeOnEscape(event) {
    if (event.key !== "Escape" || !this.previewTarget.classList.contains("is-open")) return

    this.cancelScheduledClose()
    this.close()
  }

  scheduleClose() {
    this.cancelScheduledClose()
    this.closeTimeout = setTimeout(() => this.close(), CLOSE_DELAY_MS)
  }

  cancelScheduledClose() {
    if (this.closeTimeout === null) return

    clearTimeout(this.closeTimeout)
    this.closeTimeout = null
  }

  close() {
    this.cancelScheduledClose()
    this.previewTarget.classList.remove("is-open")
  }

  invalidate() {
    this.cancelScheduledClose()
    this.abortRequest()
    this.cachedHTML = null
    this.previewTarget.replaceChildren()
    this.renderState("idle")
  }

  async load() {
    this.abortRequest()
    this.abortController = new AbortController()
    const request = this.abortController

    this.renderMessage(this.loadingTextValue)
    this.renderState("loading")

    try {
      const response = await fetch(this.urlValue, {
        credentials: "same-origin",
        // Get a 401 instead of the login page when the session has expired
        headers: { Accept: "text/html", "X-Requested-With": "XMLHttpRequest" },
        signal: request.signal
      })
      if (!response.ok) throw new Error(`Preview request failed: ${response.status}`)

      const html = await response.text()
      if (request !== this.abortController) return

      this.cachedHTML = html
      this.previewTarget.innerHTML = html
      this.renderState(this.cachedHTMLHasItems() ? "loaded" : "empty")
    } catch (error) {
      if (error.name === "AbortError" || request !== this.abortController) return

      this.renderMessage(this.errorTextValue)
      this.renderState("error")
    } finally {
      if (request === this.abortController) this.abortController = null
    }
  }

  cachedHTMLHasItems() {
    return this.previewTarget.querySelector(".quick-access-preview-item") !== null
  }

  // Loading and error share the markup of the server rendered empty state.
  renderMessage(text) {
    const message = document.createElement("p")
    message.className = "nodata"
    message.textContent = text
    this.previewTarget.replaceChildren(message)
  }

  renderState(state) {
    this.state = state
    this.previewTarget.dataset.state = state
  }

  abortRequest() {
    if (this.abortController) this.abortController.abort()
    this.abortController = null
  }

  mobileNavigationVisible() {
    const toggle = document.querySelector(".js-flyout-menu-toggle-button")
    return toggle !== null && toggle.getClientRects().length > 0
  }
}
