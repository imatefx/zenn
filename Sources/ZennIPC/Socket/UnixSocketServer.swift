import Foundation
import NIOCore
import NIOPosix
import ZennShared

/// Unix domain socket server for IPC communication.
public class UnixSocketServer {
    private let group: MultiThreadedEventLoopGroup
    private var channel: Channel?
    private let commandRouter: CommandRouter
    private let socketPath: String

    public init(commandRouter: CommandRouter, socketPath: String? = nil) {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.commandRouter = commandRouter
        self.socketPath = socketPath ?? IPCMessage.socketPath
    }

    /// Start the Unix socket server.
    public func start() throws {
        // Remove existing socket file
        try? FileManager.default.removeItem(atPath: socketPath)

        let router = commandRouter
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(.backlog, value: 256)
            .childChannelInitializer { channel in
                channel.pipeline.addHandler(SocketHandler(commandRouter: router))
            }

        channel = try bootstrap.bind(unixDomainSocketPath: socketPath).wait()
    }

    /// Stop the server.
    public func stop() {
        try? channel?.close().wait()
        try? group.syncShutdownGracefully()
        try? FileManager.default.removeItem(atPath: socketPath)
    }

    deinit {
        stop()
    }
}

/// NIO channel handler for processing IPC messages.
private final class SocketHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    private let commandRouter: CommandRouter
    private var buffer = Data()

    init(commandRouter: CommandRouter) {
        self.commandRouter = commandRouter
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var inBuffer = unwrapInboundIn(data)
        if let bytes = inBuffer.readBytes(length: inBuffer.readableBytes) {
            buffer.append(contentsOf: bytes)
        }

        processBuffer(context: context)
    }

    private func processBuffer(context: ChannelHandlerContext) {
        while buffer.count >= 4 {
            guard let length = IPCMessage.readLength(from: buffer) else { break }
            let totalLength = 4 + Int(length)
            guard buffer.count >= totalLength else { break }

            let jsonData = buffer.subdata(in: 4..<totalLength)
            buffer.removeFirst(totalLength)

            do {
                let command = try IPCMessage.decode(Command.self, from: jsonData)
                let response = commandRouter.handle(command)
                let responseData = try IPCMessage.encode(response)

                var outBuffer = context.channel.allocator.buffer(capacity: responseData.count)
                outBuffer.writeBytes(responseData)
                context.writeAndFlush(wrapOutboundOut(outBuffer), promise: nil)
            } catch {
                let errorResponse = CommandResponse.error("Failed to decode command: \(error)")
                if let responseData = try? IPCMessage.encode(errorResponse) {
                    var outBuffer = context.channel.allocator.buffer(capacity: responseData.count)
                    outBuffer.writeBytes(responseData)
                    context.writeAndFlush(wrapOutboundOut(outBuffer), promise: nil)
                }
            }
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        context.close(promise: nil)
    }
}
