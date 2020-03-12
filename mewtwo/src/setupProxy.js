const proxy = require("http-proxy-middleware")

module.exports = app => {
    app.use(proxy("/websocket", {target: "http://mewtwo.bradr.dev:8082", ws: true}))
}
