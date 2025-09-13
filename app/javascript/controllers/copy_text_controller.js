import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    issueId: Number,
    journalId: Number
  }

  async fetch(event) {
    event.preventDefault()
    try {
      let textToCopy

      if (this.hasJournalIdValue) {
        // Journal が指定されている場合
        const response = await fetch(`/issues/${this.issueIdValue}.json?include=journals`)
        if (!response.ok) throw new Error("API request failed")

        const json = await response.json()
        const journal = json.issue.journals.find(j => j.id === this.journalIdValue)
        if (!journal) throw new Error("Journal not found")

        textToCopy = journal.notes
      } else {
        // Journal がなければ Issue description
        const response = await fetch(`/issues/${this.issueIdValue}.json`)
        if (!response.ok) throw new Error("API request failed")

        const json = await response.json()
        textToCopy = json.issue.description
      }

      await copyToClipboard(textToCopy)
      alert(textToCopy)
    } catch (e) {
      alert(`Error: ${e.message}`)
    }
  }
}
