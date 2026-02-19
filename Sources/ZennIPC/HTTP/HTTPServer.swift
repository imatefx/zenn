import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import ZennShared

/// HTTP API server for REST-style access and Server-Sent Events.
public class HTTPServer {
    private let group: MultiThreadedEventLoopGroup
    private var channel: Channel?
    private let commandRouter: CommandRouter
    private let port: Int

    public init(commandRouter: CommandRouter, port: Int = IPCMessage.httpPort) {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.commandRouter = commandRouter
        self.port = port
    }

    /// Start the HTTP server.
    public func start() throws {
        let router = commandRouter
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(.backlog, value: 256)
            .childChannelInitializer { channel in
                channel.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .forwardBytes))).flatMap {
                    channel.pipeline.addHandler(HTTPResponseEncoder())
                }.flatMap {
                    channel.pipeline.addHandler(HTTPHandler(commandRouter: router))
                }
            }

        channel = try bootstrap.bind(host: "127.0.0.1", port: port).wait()
    }

    /// Stop the server.
    public func stop() {
        try? channel?.close().wait()
        try? group.syncShutdownGracefully()
    }

    deinit {
        stop()
    }
}

/// HTTP request handler.
private final class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let commandRouter: CommandRouter
    private var requestHead: HTTPRequestHead?
    private var bodyData = Data()

    init(commandRouter: CommandRouter) {
        self.commandRouter = commandRouter
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)

        switch part {
        case .head(let head):
            requestHead = head
            bodyData = Data()

        case .body(var body):
            if let bytes = body.readBytes(length: body.readableBytes) {
                bodyData.append(contentsOf: bytes)
            }

        case .end:
            guard let head = requestHead else { return }
            handleRequest(context: context, head: head, body: bodyData)
            requestHead = nil
            bodyData = Data()
        }
    }

    private func handleRequest(context: ChannelHandlerContext, head: HTTPRequestHead, body: Data) {
        let path = head.uri.split(separator: "?").first.map(String.init) ?? head.uri
        let response: CommandResponse

        switch (head.method, path) {
        case (.GET, "/api/v1/windows"):
            response = commandRouter.handle(.queryWindows)
        case (.GET, "/api/v1/workspaces"):
            response = commandRouter.handle(.queryWorkspaces)
        case (.GET, "/api/v1/monitors"):
            response = commandRouter.handle(.queryMonitors)
        case (.GET, "/api/v1/focused"):
            response = commandRouter.handle(.queryFocused)
        case (.GET, "/api/v1/tree"):
            response = commandRouter.handle(.queryTree(nil))
        case (.POST, "/api/v1/command"):
            if let command = try? JSONDecoder().decode(Command.self, from: body) {
                response = commandRouter.handle(command)
            } else {
                response = .error("Invalid command JSON")
            }
        case (.GET, "/api/v1/health"):
            response = .ok("Zenn is running")
        default:
            response = .error("Not found: \(head.method) \(path)")
        }

        sendResponse(context: context, response: response)
    }

    private func sendResponse(context: ChannelHandlerContext, response: CommandResponse) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = (try? encoder.encode(response)) ?? Data("{}".utf8)

        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "application/json")
        headers.add(name: "Content-Length", value: "\(jsonData.count)")
        headers.add(name: "Access-Control-Allow-Origin", value: "*")

        let status: HTTPResponseStatus = response.success ? .ok : .badRequest
        let head = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)

        var bodyBuffer = context.channel.allocator.buffer(capacity: jsonData.count)
        bodyBuffer.writeBytes(jsonData)
        context.write(wrapOutboundOut(.body(.byteBuffer(bodyBuffer))), promise: nil)

        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        context.close(promise: nil)
    }
}
