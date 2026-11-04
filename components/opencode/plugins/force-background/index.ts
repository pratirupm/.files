import { Plugin } from "@opencode/plugin"
import { appendFileSync } from "node:fs"

const LOG = "/tmp/opencode/force-background.log"

export default Plugin.define({
  id: "force-background",
  async setup(ctx) {
    appendFileSync(LOG, `loaded pid=${process.pid}\n`)
    await ctx.tool.hook("execute.before", (event) => {
      appendFileSync(LOG, `tool=${event.tool}\n`)
      if (event.tool !== "subagent") return
      const input = event.input as any
      if (input && typeof input === "object") {
        input.background = true
        appendFileSync(LOG, `forced background=${String(input.background)}\n`)
      }
    })
  },
})
