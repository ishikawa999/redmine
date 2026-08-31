import { Controller } from "@hotwired/stimulus"

// Manages the lazy, desktop-only preview attached to the pinned-items menu.
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

    this.open = this.open.bind(this)
    this.closeWhenOutside = this.closeWhenOutside.bind(this)
    this.closeOnEscape = this.closeOnEscape.bind(this)
    this.invalidate = this.invalidate.bind(this)

    this.element.addEventListener("pointerenter", this.open)
    this.element.addEventListener("pointerleave", this.closeWhenOutside)
    this.element.addEventListener("focusin", this.open)
    this.element.addEventListener("focusout", this.closeWhenOutside)
    document.addEventListener("keydown", this.closeOnEscape)
    document.addEventListener("pin-preview:invalidate", this.invalidate)

    this.renderState("idle")
  }

  disconnect() {
    this.element.removeEventListener("pointerenter", this.open)
    this.element.removeEventListener("pointerleave", this.closeWhenOutside)
    this.element.removeEventListener("focusin", this.open)
    this.element.removeEventListener("focusout", this.closeWhenOutside)
    document.removeEventListener("keydown", this.closeOnEscape)
    document.removeEventListener("pin-preview:invalidate", this.invalidate)
    this.abortRequest()
  }

  open() {
    if (this.mobileNavigationVisible()) return

    this.previewTarget.classList.add("is-open")

    if (this.cachedHTML !== null) {
      // Keep existing links intact when focus moves inside the preview.
      this.renderState(this.cachedHTMLHasItems() ? "loaded" : "empty")
    } else if (this.state === "idle") {
      this.load()
    }
  }

  closeWhenOutside(event) {
    if (event.relatedTarget && this.element.contains(event.relatedTarget)) return

    this.close()
  }

  closeOnEscape(event) {
    if (event.key !== "Escape" || !this.previewTarget.classList.contains("is-open")) return

    this.close()
  }

  close() {
    this.previewTarget.classList.remove("is-open")
  }

  invalidate() {
    this.abortRequest()
    this.cachedHTML = null
    this.previewTarget.replaceChildren()
    this.renderState("idle")
  }

  async load() {
    this.abortRequest()
    this.abortController = new AbortController()
    const request = this.abortController

    this.previewTarget.textContent = this.loadingTextValue
    this.renderState("loading")

    try {
      const response = await fetch(this.urlValue, {
        credentials: "same-origin",
        headers: { Accept: "text/html" },
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

      this.previewTarget.textContent = this.errorTextValue
      this.renderState("error")
    } finally {
      if (request === this.abortController) this.abortController = null
    }
  }

  cachedHTMLHasItems() {
    return this.previewTarget.querySelector(".pin-preview-item") !== null
  }

  renderState(state) {
    this.state = state
    this.previewTarget.dataset.state = state
    this.previewTarget.classList.toggle("is-loading", state === "loading")
    this.previewTarget.classList.toggle("is-empty", state === "empty")
    this.previewTarget.classList.toggle("is-error", state === "error")
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
