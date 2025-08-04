import { Controller } from '@hotwired/stimulus'

class ListAutofillHandler {
  constructor(inputElement, format) {
    this.input = inputElement
    this.format = format
  }

  run(event) {
    const { selectionStart, value } = this.input

    const beforeCursor = value.slice(0, selectionStart)
    const lines = beforeCursor.split("\n")
    const currentLine = lines[lines.length - 1]
    const lineStartPos = beforeCursor.lastIndexOf("\n") + 1

    let formatter = null

    switch (this.format) {
      case "common_mark":
        formatter = new CommonMarkListFormatter()
        break
      case "textile":
        formatter = new TextileListFormatter()
        break
      default:
        return
    }

    const result = formatter.format(currentLine)

    if (!result) return

    event.preventDefault()

    switch (result.action) {
      case "remove":
        const beforeLine = value.slice(0, lineStartPos)
        const afterCursor = value.slice(selectionStart)
        this.input.value = beforeLine + afterCursor
        this.input.setSelectionRange(lineStartPos, lineStartPos)
        break

      case "insert":
        const insertText = "\n" + result.text
        const newValue = value.slice(0, selectionStart) + insertText + value.slice(selectionStart)
        const newCursor = selectionStart + insertText.length
        this.input.value = newValue
        this.input.setSelectionRange(newCursor, newCursor)
        break
      default:
        return
    }
  }
}


class CommonMarkListFormatter {
  format(line) {
    const match = line.match(/^(\s*)((\d+)\.|[*\-+])\s*(.*)$/)
    if (!match) return null

    const indent = match[1]
    const marker = match[2]
    const number = match[3]
    const content = match[4]

    if (content.trim() === "") {
      return { action: "remove" }
    }

    if (number) {
      const nextNumber = parseInt(number, 10) + 1
      return { action: "insert", text: `${indent}${nextNumber}. ` }
    } else {
      return { action: "insert", text: `${indent}${marker} ` }
    }
  }
}

class TextileListFormatter {
  format(line) {
    const match = line.match(/^([*#]+)\s*(.*)$/);
    if (!match) return null;

    const marker = match[1];
    const content = match[2];

    if (content.trim().length === 0) {
      return { action: "remove" };
    }

    return { action: "insert", text: `${marker} ` };
  }
}

export default class extends Controller {
  static targets = ['input']

  connect() {
    this.inputTarget.addEventListener('compositionstart', this.handleCompositionStart)
    this.inputTarget.addEventListener('compositionend', this.handleCompositionEnd)
    this.isComposing = false
  }

  disconnect() {
    this.inputTarget.removeEventListener('compositionstart', this.handleCompositionStart)
    this.inputTarget.removeEventListener('compositionend', this.handleCompositionEnd)
  }

  handleCompositionStart = () => {
    this.isComposing = true
  }

  handleCompositionEnd = () => {
    this.isComposing = false
  }

  handleEnter(event) {
    if (this.isComposing || event.key !== 'Enter') return

    const format = event.params.textFormatting
    const handler = new ListAutofillHandler(this.inputTarget, format)
    handler.run(event)
  }
}
