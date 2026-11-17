/// A rectangle on the original photograph, in pixels.
class BoundingBox {
  const BoundingBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) => BoundingBox(
    x1: (json['x1'] as num).toInt(),
    y1: (json['y1'] as num).toInt(),
    x2: (json['x2'] as num).toInt(),
    y2: (json['y2'] as num).toInt(),
  );

  final int x1;
  final int y1;
  final int x2;
  final int y2;

  int get width => x2 - x1;
  int get height => y2 - y1;

  Map<String, dynamic> toJson() => {'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2};

  @override
  bool operator ==(Object other) =>
      other is BoundingBox &&
      other.x1 == x1 &&
      other.y1 == y1 &&
      other.x2 == x2 &&
      other.y2 == y2;

  @override
  int get hashCode => Object.hash(x1, y1, x2, y2);

  @override
  String toString() => 'BoundingBox($x1, $y1, $x2, $y2)';
}

/// One finding of the model: which class, how sure, and where.
class Detection {
  const Detection({
    required this.classId,
    required this.confidence,
    required this.box,
  });

  factory Detection.fromJson(Map<String, dynamic> json) => Detection(
    // The server calls the field "label" in the web payload and "class_id"
    // in /api/v1; both hold the raw class key.
    classId: (json['class_id'] ?? json['label']) as String,
    confidence: (json['confidence'] as num).toDouble(),
    box: BoundingBox.fromJson(json['box'] as Map<String, dynamic>),
  );

  /// Raw class key stored in the model, for example `karat_daun`.
  final String classId;

  /// Score of this detection in percent (0-100), rounded to two decimals.
  final double confidence;

  final BoundingBox box;

  Map<String, dynamic> toJson() => {
    'class_id': classId,
    'confidence': confidence,
    'box': box.toJson(),
  };

  @override
  String toString() => 'Detection($classId, $confidence%, $box)';
}
