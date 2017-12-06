//
//  ConnectionManager.swift
//  CrayonPrototype
//
//  Created by Antonio Llongueras on 12/4/17.
//  Copyright © 2017 Crayon. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import ARKit

protocol ConnectionManagerDelegate {
    
    func connectedDevicesChanged(manager : ConnectionManager, connectedDevices: [String])
    func locationChanged(manager : ConnectionManager, location: matrix_float4x4)
    func syncUpdate(manager: ConnectionManager, location: matrix_float4x4)
    
}

enum PingType {
    case update
    case sync
    
    var description: String {
        switch self {
        case .update:
            return "update_ping"
        case .sync:
            return "sync_ping"
        }
    }
}

class ConnectionManager: NSObject {
    private let connectionType = "location-share"
    
    private let myPeerId = MCPeerID(displayName: UIDevice.current.name)
    private let serviceAdvertiser: MCNearbyServiceAdvertiser
    private let serviceBrowser: MCNearbyServiceBrowser
    
    lazy var session : MCSession = {
        let session = MCSession(peer: self.myPeerId, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        return session
    }()
    
    var delegate: ConnectionManagerDelegate?
    
    override init() {
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: connectionType)
        serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: connectionType)
        super.init()
        
        serviceAdvertiser.delegate = self
        serviceAdvertiser.startAdvertisingPeer()
        
        serviceBrowser.delegate = self
        serviceBrowser.startBrowsingForPeers()
    }
    
    func send(location: (String, String, String)) {
        NSLog("%@", "sendLocation: \(location) to \(session.connectedPeers.count) peers")
        let locationString = "\(location.0),\(location.1),\(location.2)"
        if session.connectedPeers.count > 0 {
            do {
                try self.session.send(locationString.data(using: .utf8)!, toPeers: session.connectedPeers, with: .reliable)
            }
            catch let error {
                NSLog("%@", "Error for sending: \(error)")
            }
        }
    }
    
    func sync(transform: matrix_float4x4) {
        if session.connectedPeers.count > 0 {
            do {
                try self.session.send(archiveMatrix(transform, pingType: .sync), toPeers: session.connectedPeers, with: .reliable)
            }
            catch let error {
                NSLog("%@", "Error for sending: \(error)")
            }
        }
    }
    
    func send(transform: matrix_float4x4) {
        if session.connectedPeers.count > 0 {
            do {
                try self.session.send(archiveMatrix(transform, pingType: .update), toPeers: session.connectedPeers, with: .reliable)
            }
            catch let error {
                NSLog("%@", "Error for sending: \(error)")
            }
        }
    }
    
    private func archiveMatrix(_ transform: matrix_float4x4, pingType ping: PingType) -> Data {
        let column0 = [String(transform.columns.0.w), String(transform.columns.0.x), String(transform.columns.0.y), String(transform.columns.0.z)]
        let column1 = [String(transform.columns.1.w), String(transform.columns.1.x), String(transform.columns.1.y), String(transform.columns.1.z)]
        let column2 = [String(transform.columns.2.w), String(transform.columns.2.x), String(transform.columns.2.y), String(transform.columns.2.z)]
        let column3 = [String(transform.columns.3.w), String(transform.columns.3.x), String(transform.columns.3.y), String(transform.columns.3.z)]

        let columnsArray = [column0, column1, column2, column3]
        let dict = ["columnsArray" : columnsArray, "pingType" : ping.description] as [String : Any]
        let archivedTransform = NSKeyedArchiver.archivedData(withRootObject: dict)
        return archivedTransform
    }
    
    private func unarchiveDataMatrix(_ data: Data) -> (pingType: PingType, matrix: matrix_float4x4) {
        let dict = NSKeyedUnarchiver.unarchiveObject(with: data) as! [String : Any]
        
        let pingDescription = dict["pingType"] as! String
        var pingType: PingType!
        if pingDescription == PingType.sync.description {
            pingType = .sync
        } else
        if pingDescription == PingType.update.description {
            pingType = .update
        }
        
        var columnsArray = dict["columnsArray"] as! [[String]]
        
        var matrix: matrix_float4x4 = simd_float4x4()
        matrix.columns.0.w = Float(columnsArray[0][0])!
        matrix.columns.0.x = Float(columnsArray[0][1])!
        matrix.columns.0.y = Float(columnsArray[0][2])!
        matrix.columns.0.z = Float(columnsArray[0][3])!

        matrix.columns.1.w = Float(columnsArray[1][0])!
        matrix.columns.1.x = Float(columnsArray[1][1])!
        matrix.columns.1.y = Float(columnsArray[1][2])!
        matrix.columns.1.z = Float(columnsArray[1][3])!

        matrix.columns.2.w = Float(columnsArray[2][0])!
        matrix.columns.2.x = Float(columnsArray[2][1])!
        matrix.columns.2.y = Float(columnsArray[2][2])!
        matrix.columns.2.z = Float(columnsArray[2][3])!

        matrix.columns.3.w = Float(columnsArray[3][0])!
        matrix.columns.3.x = Float(columnsArray[3][1])!
        matrix.columns.3.y = Float(columnsArray[3][2])!
        matrix.columns.3.z = Float(columnsArray[3][3])!

        return (pingType, matrix)
    }
    
    deinit {
        serviceAdvertiser.stopAdvertisingPeer()
        serviceBrowser.stopBrowsingForPeers()
    }
}

extension ConnectionManager : MCNearbyServiceAdvertiserDelegate {
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        NSLog("%@", "didNotStartAdvertisingPeer: \(error)")
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        NSLog("%@", "didReceiveInvitationFromPeer \(peerID)")
        invitationHandler(true, self.session)
    }
    
}

extension ConnectionManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        NSLog("%@", "didNotStartBrowsingForPeers: \(error)")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        NSLog("%@", "foundPeer: \(peerID)")
        NSLog("%@", "invitePeer: \(peerID)")
        browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("%@", "lostPeer: \(peerID)")
    }
}

extension ConnectionManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        NSLog("%@", "peer \(peerID) didChangeState: \(state)")
        delegate?.connectedDevicesChanged(manager: self, connectedDevices: session.connectedPeers.map{$0.displayName})
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {        
        let unarchivedPing = unarchiveDataMatrix(data)
        
        switch unarchivedPing.pingType {
        case .sync:
            delegate?.syncUpdate(manager: self, location: unarchivedPing.matrix)
        case .update:
            delegate?.locationChanged(manager: self, location: unarchivedPing.matrix)
        }
//        let str = String(data: data, encoding: .utf8)!
//        let stringArray = str.components(separatedBy: ",")
//        let locations = (stringArray[0], stringArray[1], stringArray[2])
//
//        delegate?.locationChanged(manager: self, location: locations)
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        NSLog("%@", "didReceiveStream")
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        NSLog("%@", "didStartReceivingResourceWithName")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        NSLog("%@", "didFinishReceivingResourceWithName")
    }
}

extension String {
    var data: Data { return Data(utf8) }
}

extension Numeric {
    var data: Data {
        var source = self
        // This will return 1 byte for 8-bit, 2 bytes for 16-bit, 4 bytes for 32-bit and 8 bytes for 64-bit binary integers. For floating point types it will return 4 bytes for single-precision, 8 bytes for double-precision and 16 bytes for extended precision.
        return Data(bytes: &source, count: MemoryLayout<Self>.size)
    }
}

extension Data {
    var integer: Int {
        return withUnsafeBytes { $0.pointee }
    }
    var int32: Int32 {
        return withUnsafeBytes { $0.pointee }
    }
    var float: Float {
        return withUnsafeBytes { $0.pointee }
    }
    var double: Double {
        return withUnsafeBytes { $0.pointee }
    }
    var string: String {
        return String(data: self, encoding: .utf8) ?? ""
    }
}
