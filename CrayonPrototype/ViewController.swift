//
//  ViewController.swift
//  CrayonPrototype
//
//  Created by Antonio Llongueras on 12/4/17.
//  Copyright © 2017 Crayon. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    let connectionManager = ConnectionManager()
    
    var syncTransform: matrix_float4x4?
    var previousTransform: matrix_float4x4?
    var syncColumn: SCNVector3?
    var shipNode: SCNNode?
    
    var synced: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
        
        connectionManager.delegate = self
        
        sceneView.scene.rootNode.childNodes.forEach { (node) in
            if node.name == "ship" {
                shipNode = node
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    @IBAction func sync(_ sender: AnyObject) {
        if let currentFrame = sceneView.session.currentFrame {
            connectionManager.sync(transform: currentFrame.camera.transform)
        }
    }
    
    @IBAction func left(sender: AnyObject) {
        shipNode?.position.x -= 0.05
    }
    
    @IBAction func right(sender: AnyObject) {
        shipNode?.position.x += 0.05
    }
    
    @IBAction func up(sender: AnyObject) {
        shipNode?.position.y += 0.05
    }
    
    @IBAction func down(sender: AnyObject) {
        shipNode?.position.y -= 0.05
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        print("new node")
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if let currentFrame = sceneView.session.currentFrame {
            connectionManager.send(transform: currentFrame.camera.transform)
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}

extension ViewController: ConnectionManagerDelegate {
    func connectedDevicesChanged(manager: ConnectionManager, connectedDevices: [String]) {
        
    }
    
    func locationChanged(manager: ConnectionManager, location: matrix_float4x4) {
        print("Received Location: \(location)")
        
        guard synced else { return }
        
        guard let previousTransform = previousTransform else {
            self.previousTransform = location
            return
        }
        
        let prevPos = previousTransform.position()
        let newPos = location.position()
        
        let posDiff = SCNVector3Make(newPos.x - prevPos.x, newPos.y - prevPos.y, newPos.z - prevPos.z)
        
        shipNode?.position.x += posDiff.x
        shipNode?.position.y += posDiff.y
        shipNode?.position.z += posDiff.z
        
//        shipNode? = SCNMatrix4(location)

//        if let syncC = syncColumn {
//           let post =  SCNVector3(syncC.x + location.columns.3.x,
//                       syncC.y + location.columns.3.y,
//                       syncC.z + location.columns.3.z)
//
//            shipNode?.position = post
//        }
    }
    
    func syncUpdate(manager: ConnectionManager, location: matrix_float4x4) {
        print("Received sync call for location: \(location)")
        
        synced = true
//        if let currentFrame = sceneView.session.currentFrame {
//            syncTransform = location - currentFrame.camera.transform
//            syncColumn = SCNVector3Make(location.columns.3.x - currentFrame.camera.transform.columns.3.x,
//                                        location.columns.3.y - currentFrame.camera.transform.columns.3.y,
//                                        location.columns.3.z - currentFrame.camera.transform.columns.3.z)
//        }
    }
    
    
}

extension matrix_float4x4 {
    func position() -> SCNVector3 {
        return SCNVector3(columns.3.x, columns.3.y, columns.3.z)
    }
}
