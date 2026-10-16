// node --test
const test = require("node:test")
const assert = require("node:assert")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

// The module is a QML JavaScript library; minus its pragma it is plain script.
const source = fs.readFileSync(path.join(__dirname, "../components/WebApps.js"), "utf8")
function load() {
  const WebApps = vm.createContext({})
  vm.runInContext(source.replace(/^\.pragma library$/m, ""), WebApps)
  return WebApps
}

// Desktop entries as Quickshell hands them over: the icon and the split Exec.
const entries = [
  { icon: "/home/u/.local/share/applications/icons/Facebook.png", command: ["omarchy-launch-webapp", "https://facebook.com"] },
  { icon: "/home/u/.local/share/applications/icons/Gmail.png", command: ["omarchy-launch-webapp", "https://gmail.com"] },
  { icon: "discord-web", command: ["chromium", "--app=https://discord.com/channels/@me"] },
  { icon: "/icons/Home.png", command: ["omarchy-launch-webapp", "http://192.168.1.5:8080/"] },
  { icon: "firefox", command: ["firefox", "%u"] },
]

function body(url, text = "Something happened") {
  return `<a href="${url}">${url.replace(/^https?:\/\//, "")}</a>\n\n${text}`
}

test("the leading origin picks the web app's icon", () => {
  const WebApps = load()
  assert.strictEqual(WebApps.lookup(body("https://www.facebook.com/"), entries), entries[0].icon)
  assert.strictEqual(WebApps.lookup(body("https://discord.com/"), entries), "discord-web")
})

test("a subdomain falls back to the site's web app", () => {
  assert.strictEqual(load().lookup(body("https://m.facebook.com/"), entries), entries[0].icon)
})

test("Gmail notifies from mail.google.com", () => {
  assert.strictEqual(load().lookup(body("https://mail.google.com/"), entries), entries[1].icon)
})

test("a self-hosted app matches on its port", () => {
  const WebApps = load()
  assert.strictEqual(WebApps.lookup(body("http://192.168.1.5:8080/"), entries), "/icons/Home.png")
  assert.strictEqual(WebApps.lookup(body("http://192.168.1.5:9090/"), entries), "")
})

test("a site without a web app, or a body without a leading link, changes nothing", () => {
  const WebApps = load()
  assert.strictEqual(WebApps.lookup(body("https://github.com/"), entries), "")
  assert.strictEqual(WebApps.lookup(`New message ${body("https://facebook.com/")}`, entries), "")
  assert.strictEqual(WebApps.lookup("", entries), "")
})

test("a web app installed later is found", () => {
  const WebApps = load()
  assert.strictEqual(WebApps.lookup(body("https://github.com/"), entries), "")
  const more = entries.concat([{ icon: "github-web", command: ["omarchy-launch-webapp", "https://github.com"] }])
  assert.strictEqual(WebApps.lookup(body("https://github.com/"), more), "github-web")
})
