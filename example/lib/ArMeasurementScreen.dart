import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

class ArMeasurementScreen extends StatefulWidget {
  const ArMeasurementScreen({Key? key}) : super(key: key);

  @override
  State<ArMeasurementScreen> createState() => _ArMeasurementScreenState();
}

class _ArMeasurementScreenState extends State<ArMeasurementScreen> {
  late ARKitController arKitController;
  late ARKitPlane plane;
  late ARKitNode node;
  vector.Vector3? lastPosition;
  late String anchorId;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          child: ARKitSceneView(
            showFeaturePoints: true,
            planeDetection: ARPlaneDetection.horizontal,
            onARKitViewCreated: onARViewCreated,
            enableTapRecognizer: true,
          ),
        ),
      );
  void onARViewCreated(ARKitController arKitController) {
    this.arKitController = arKitController;
    this.arKitController.onAddNodeForAnchor = addAnchor;
    this.arKitController.onUpdateNodeForAnchor = updateAnchor;
    this.arKitController.onARTap = (List<ARKitTestResult> ar) {
        final planeTap = ar.firstWhere((tap) => tap.type == ARKitHitTestResultType.existingPlaneUsingExtent, 
        // orElse: () => null, 
      );
      if (planeTap != null) {
        onPlaneTapHandler(planeTap.worldTransform);
      }
    };
  }

  void addAnchor(ARKitAnchor anchor) {
    if (anchor is! ARKitPlaneAnchor) {
      return;
    }
    addPlane(arKitController, anchor);
  }

  void addPlane(ARKitController controller, ARKitPlaneAnchor anchor) {
    anchorId = anchor.identifier;

    plane =
        ARKitPlane(width: anchor.extent.x, height: anchor.extent.z, materials: [
      ARKitMaterial(
          transparency: 0.5, diffuse: ARKitMaterialProperty.color(Colors.white))
    ]);

    node = ARKitNode(
      geometry: plane,
      position: vector.Vector3(anchor.center.x, 0, anchor.center.z),
      rotation: vector.Vector4(1, 0, 0, -math.pi / 2),
    );

    controller.add(node, parentNodeName: anchor.nodeName);
  }

  void updateAnchor(ARKitAnchor anchor) {
    if (anchor.identifier != anchorId) {
      return;
    }

    final ARKitPlaneAnchor planeAnchor = anchor as ARKitPlaneAnchor;
    node.position =
        vector.Vector3(planeAnchor.center.x, 0, planeAnchor.center.z);
    plane.width.value = planeAnchor.extent.x;
    plane.height.value = planeAnchor.extent.z;
  }

  void onPlaneTapHandler(Matrix4 transform) {
    final position = vector.Vector3(transform.getColumn(3).x,
        transform.getColumn(3).y, transform.getColumn(3).z);

    final material = ARKitMaterial(
        lightingModelName: ARKitLightingModel.constant,
        diffuse:
            ARKitMaterialProperty.color(const Color.fromRGBO(255, 153, 83, 1)));

    final sphere = ARKitSphere(radius: 0.003, materials: [material]);

    final node = ARKitNode(geometry: sphere, position: position);

    arKitController.add(node);

    if (lastPosition != null) {
      final line = ARKitLine(fromVector: lastPosition as vector.Vector3, toVector: position);

      final lineNode = ARKitNode(geometry: line);

      arKitController.add(lineNode);

      final distance = calculateDistanceBetweenPoint(position, lastPosition as vector.Vector3);
      final point = getMiddleVector(position, lastPosition as vector.Vector3);
      drawText(distance, point);
    }
    lastPosition = position;
  }

  String calculateDistanceBetweenPoint(vector.Vector3 A, vector.Vector3 B) {
    final length = A.distanceTo(B);
    return '${(length * 100).toStringAsFixed(2)} cm';
  }

  vector.Vector3 getMiddleVector(vector.Vector3 A, vector.Vector3 B) {
    return vector.Vector3(
      (A.x + B.x) / 2,
      (A.y + B.y) / 2,
      (A.z + B.z) / 2,
    );
  }

  void drawText(String textDistance, vector.Vector3 point) {
    final textGeometry = ARKitText(
      text: textDistance, 
      extrusionDepth: 1,
      materials: [
        ARKitMaterial(
          diffuse: ARKitMaterialProperty.color(Colors.red),
        )
      ]
      );

      const scale = 0.001;
      final vectorScale = vector.Vector3(scale, scale, scale);

      final node = ARKitNode(
        geometry: textGeometry,
        position: point,
        scale: vectorScale
      );

      arKitController.getNodeBoundingBox(node)
      .then((List<vector.Vector3> result) {
        final minVector = result[0];
        final maxVector = result[1];

        final dx = (maxVector.x - minVector.x) / 2 * scale;
        final dy = (maxVector.y - minVector.y) / 2 * scale;

        final position = vector.Vector3(
          node.position.x - dx,
          node.position.y - dy,
          node.position.z
        );
        node.position = position;
      });
      arKitController.add(node);
  }
}
