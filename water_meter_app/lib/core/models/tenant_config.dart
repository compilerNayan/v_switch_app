class TenantWing {
  const TenantWing({
    required this.name,
    this.floorCount = 0,
  });

  factory TenantWing.fromJson(Map<String, dynamic> json) {
    return TenantWing(
      name: json['name'] as String? ?? '',
      floorCount: json['floorCount'] as int? ?? 0,
    );
  }

  final String name;
  final int floorCount;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (floorCount > 0) 'floorCount': floorCount,
      };

  TenantWing copyWith({String? name, int? floorCount}) {
    return TenantWing(
      name: name ?? this.name,
      floorCount: floorCount ?? this.floorCount,
    );
  }
}

class TenantBlock {
  const TenantBlock({
    required this.id,
    required this.label,
    this.wings = const [],
  });

  factory TenantBlock.fromJson(Map<String, dynamic> json) {
    final rawWings = json['wings'] as List<dynamic>? ?? const [];
    return TenantBlock(
      id: json['id'] as String,
      label: json['label'] as String? ?? json['id'] as String,
      wings: rawWings
          .map((w) => TenantWing.fromJson(w as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String label;
  final List<TenantWing> wings;

  List<String> get wingNames => wings.map((w) => w.name).toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'wings': wings.map((w) => w.toJson()).toList(),
      };

  TenantBlock copyWith({
    String? id,
    String? label,
    List<TenantWing>? wings,
  }) {
    return TenantBlock(
      id: id ?? this.id,
      label: label ?? this.label,
      wings: wings ?? this.wings,
    );
  }
}

class TenantStructure {
  const TenantStructure({this.blocks = const []});

  factory TenantStructure.fromJson(Map<String, dynamic> json) {
    final blocks = (json['blocks'] as List<dynamic>?)
            ?.map((e) => TenantBlock.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    return TenantStructure(blocks: blocks);
  }

  final List<TenantBlock> blocks;

  bool get hasBlocks => blocks.isNotEmpty;

  bool get hasWings => blocks.any((b) => b.wings.isNotEmpty);

  bool get hasFloors => blocks.any(
        (b) => b.wings.any((w) => w.floorCount > 0),
      );

  List<String> get blockIds => blocks.map((b) => b.id).toList();

  List<String> wingsForBlock(String blockId) {
    for (final block in blocks) {
      if (block.id == blockId) return block.wingNames;
    }
    return const [];
  }

  int floorCountForWing(String blockId, String wingName) {
    for (final block in blocks) {
      if (block.id != blockId) continue;
      for (final wing in block.wings) {
        if (wing.name == wingName) return wing.floorCount;
      }
    }
    return 0;
  }

  bool isValidBlock(String? blockId) {
    if (!hasBlocks) return true;
    if (blockId == null || blockId.isEmpty) return false;
    return blocks.any((b) => b.id == blockId);
  }

  bool isValidWing(String? blockId, String? wing) {
    if (!hasWings) return true;
    if (wing == null || wing.isEmpty) return false;
    return wingsForBlock(blockId ?? '').contains(wing);
  }

  Map<String, dynamic> toJson() => {
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };
}

class TenantConfig {
  const TenantConfig({
    required this.tenantId,
    required this.name,
    this.structure = const TenantStructure(),
  });

  factory TenantConfig.fromJson(Map<String, dynamic> json) {
    return TenantConfig(
      tenantId: json['tenantId'] as String,
      name: json['name'] as String,
      structure: json['structure'] != null
          ? TenantStructure.fromJson(json['structure'] as Map<String, dynamic>)
          : const TenantStructure(),
    );
  }

  final String tenantId;
  final String name;
  final TenantStructure structure;

  bool get hasBlocks => structure.hasBlocks;
  bool get hasWings => structure.hasWings;
  bool get hasFloors => structure.hasFloors;

  Map<String, dynamic> toJson() => {
        'tenantId': tenantId,
        'name': name,
        'structure': structure.toJson(),
      };

  TenantConfig copyWith({
    String? tenantId,
    String? name,
    TenantStructure? structure,
  }) {
    return TenantConfig(
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      structure: structure ?? this.structure,
    );
  }
}
