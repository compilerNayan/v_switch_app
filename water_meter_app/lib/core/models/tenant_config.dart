class TenantBlock {
  const TenantBlock({
    required this.id,
    required this.label,
    this.wings = const [],
  });

  factory TenantBlock.fromJson(Map<String, dynamic> json) {
    return TenantBlock(
      id: json['id'] as String,
      label: json['label'] as String? ?? json['id'] as String,
      wings: (json['wings'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  final String id;
  final String label;
  final List<String> wings;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'wings': wings,
      };

  TenantBlock copyWith({
    String? id,
    String? label,
    List<String>? wings,
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

  List<String> get blockIds => blocks.map((b) => b.id).toList();

  List<String> wingsForBlock(String blockId) {
    for (final block in blocks) {
      if (block.id == blockId) return block.wings;
    }
    return const [];
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
