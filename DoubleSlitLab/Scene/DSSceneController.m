#import "DSSceneController.h"
#import "DSExperimentParameters.h"
#import "DSColorScience.h"
#import "DSTheme.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static const CGFloat DSBeamHeight = 0.52;

@interface DSSceneController ()
@property (nonatomic, strong) SCNView *sceneView;
@property (nonatomic, strong) SCNScene *scene;
@property (nonatomic, strong) SCNNode *cameraNode;
@property (nonatomic, strong) SCNNode *worldRoot;
@property (nonatomic, strong) SCNNode *labelsGroup;
@property (nonatomic, strong) SCNNode *beamGroup;
@property (nonatomic, strong) SCNNode *fanNode;
@property (nonatomic, strong) SCNNode *apertureGlowNode;
@property (nonatomic, strong) SCNNode *laserLensNode;
@property (nonatomic, strong) SCNMaterial *screenMaterial;
@property (nonatomic, strong) NSImage *patternImage;
@property (nonatomic, strong) NSImage *breadboardImage;
@property (nonatomic, strong) NSColor *accentColor;
@property (nonatomic, readwrite) BOOL labelsVisible;
@property (nonatomic) BOOL shutterOpen;
@property (nonatomic) BOOL didInitialFit;
@property (nonatomic) double lastLaserDistance;
@property (nonatomic) double lastScreenDistance;
@end

@implementation DSSceneController

- (instancetype)initWithSceneView:(SCNView *)sceneView {
    self = [super init];
    if (self) {
        _sceneView = sceneView;
        _labelsVisible = YES;
        _shutterOpen = YES;
        _accentColor = [NSColor whiteColor];
        _lastLaserDistance = -1.0;
        _lastScreenDistance = -1.0;
        [self configureScene];
    }
    return self;
}

- (void)configureScene {
    self.scene = [SCNScene scene];
    self.scene.background.contents = [NSColor colorWithSRGBRed:0.016 green:0.026 blue:0.041 alpha:1.0];

    self.worldRoot = [SCNNode node];
    self.worldRoot.name = @"experiment";
    [self.scene.rootNode addChildNode:self.worldRoot];

    self.cameraNode = [SCNNode node];
    self.cameraNode.name = @"camera";
    SCNCamera *camera = [SCNCamera camera];
    camera.fieldOfView = 40.0;
    camera.zNear = 0.02;
    camera.zFar = 400.0;
    camera.wantsHDR = NO;
    self.cameraNode.camera = camera;
    [self.scene.rootNode addChildNode:self.cameraNode];

    [self addLights];
    [self addFloor];

    self.sceneView.scene = self.scene;
    self.sceneView.pointOfView = self.cameraNode;
    self.sceneView.allowsCameraControl = YES;
    self.sceneView.autoenablesDefaultLighting = NO;
    self.sceneView.antialiasingMode = SCNAntialiasingModeMultisampling4X;
    self.sceneView.preferredFramesPerSecond = 60;
    self.sceneView.rendersContinuously = YES;
    self.sceneView.backgroundColor = [NSColor colorWithSRGBRed:0.016 green:0.026 blue:0.041 alpha:1.0];
    self.sceneView.wantsLayer = YES;
    self.sceneView.layer.backgroundColor = self.sceneView.backgroundColor.CGColor;
}

- (void)addLights {
    SCNNode *ambientNode = [SCNNode node];
    SCNLight *ambient = [SCNLight light];
    ambient.type = SCNLightTypeAmbient;
    ambient.color = [NSColor colorWithSRGBRed:0.72 green:0.80 blue:1.0 alpha:1.0];
    ambient.intensity = 330.0;
    ambientNode.light = ambient;
    [self.scene.rootNode addChildNode:ambientNode];

    SCNNode *keyNode = [SCNNode node];
    SCNLight *key = [SCNLight light];
    key.type = SCNLightTypeDirectional;
    key.color = [NSColor colorWithSRGBRed:1.0 green:0.96 blue:0.90 alpha:1.0];
    key.intensity = 950.0;
    key.castsShadow = YES;
    key.shadowMode = SCNShadowModeDeferred;
    key.shadowSampleCount = 16;
    key.shadowRadius = 4.0;
    key.shadowColor = [NSColor colorWithWhite:0.0 alpha:0.48];
    key.shadowMapSize = CGSizeMake(2048.0, 2048.0);
    key.orthographicScale = 5.0;
    keyNode.light = key;
    keyNode.eulerAngles = SCNVector3Make(-0.95, 0.55, 0.10);
    [self.scene.rootNode addChildNode:keyNode];

    SCNNode *fillNode = [SCNNode node];
    SCNLight *fill = [SCNLight light];
    fill.type = SCNLightTypeOmni;
    fill.color = [NSColor colorWithSRGBRed:0.46 green:0.63 blue:1.0 alpha:1.0];
    fill.intensity = 220.0;
    fillNode.light = fill;
    fillNode.position = SCNVector3Make(2.2, 2.0, 1.0);
    [self.scene.rootNode addChildNode:fillNode];
}

- (void)addFloor {
    SCNFloor *floor = [SCNFloor floor];
    floor.reflectivity = 0.045;
    floor.reflectionFalloffEnd = 3.0;
    SCNMaterial *material = [SCNMaterial material];
    material.lightingModelName = SCNLightingModelPhysicallyBased;
    material.diffuse.contents = [NSColor colorWithSRGBRed:0.035 green:0.046 blue:0.063 alpha:1.0];
    material.roughness.contents = @0.88;
    material.metalness.contents = @0.15;
    floor.materials = @[material];
    SCNNode *floorNode = [SCNNode nodeWithGeometry:floor];
    floorNode.position = SCNVector3Make(0.0, -0.72, 0.0);
    floorNode.name = @"floor";
    [self.scene.rootNode addChildNode:floorNode];
}

#pragma mark - Public

- (void)applyParameters:(DSExperimentParameters *)parameters {
    if (!parameters) {
        return;
    }
    double laserDistance = parameters.laserDistanceM;
    double screenDistance = parameters.screenDistanceM;
    BOOL distancesChanged = fabs(laserDistance - self.lastLaserDistance) > 1e-5 ||
                            fabs(screenDistance - self.lastScreenDistance) > 1e-5;

    self.accentColor = parameters.beamColor ?: DSColorForWavelength(parameters.wavelengthNm);
    _shutterOpen = parameters.shutterOpen;

    [self rebuildWorldWithParameters:parameters];

    if (!self.didInitialFit || distancesChanged) {
        [self fitCameraForLaserDistance:laserDistance screenDistance:screenDistance animated:self.didInitialFit];
        self.didInitialFit = YES;
    }
    self.lastLaserDistance = laserDistance;
    self.lastScreenDistance = screenDistance;
}

- (void)setPatternImage:(NSImage *)image {
    _patternImage = image;
    [self updateScreenAppearance];
}

- (void)setShutterOpen:(BOOL)open {
    _shutterOpen = open;
    self.beamGroup.hidden = !open;
    self.fanNode.hidden = !open;
    self.apertureGlowNode.hidden = !open;
    if (self.laserLensNode) {
        self.laserLensNode.opacity = open ? 1.0 : 0.25;
    }
    [self updateScreenAppearance];
}

- (void)setLabelsVisible:(BOOL)visible {
    _labelsVisible = visible;
    self.labelsGroup.hidden = !visible;
}

- (void)resetCamera {
    double laserDistance = self.lastLaserDistance;
    double screenDistance = self.lastScreenDistance;
    if (laserDistance < 0.0) {
        laserDistance = 0.5;
    }
    if (screenDistance < 0.0) {
        screenDistance = 1.5;
    }
    [self fitCameraForLaserDistance:laserDistance screenDistance:screenDistance animated:YES];
}

#pragma mark - World construction

- (void)rebuildWorldWithParameters:(DSExperimentParameters *)p {
    for (SCNNode *child in [self.worldRoot.childNodes copy]) {
        [child removeFromParentNode];
    }

    double laserDistance = p.laserDistanceM;
    double screenDistance = p.screenDistanceM;
    double centerZ = (screenDistance - laserDistance) * 0.5;
    double tableLength = laserDistance + screenDistance + 0.9;

    [self buildTableWithLength:tableLength centerZ:centerZ];
    [self buildLaserAtZ:-laserDistance parameters:p];
    [self buildApertureWithParameters:p];
    [self buildScreenAtZ:screenDistance parameters:p];
    [self buildBeamFromZ:-laserDistance toZ:0.0 parameters:p];
    [self buildFanToScreenAtZ:screenDistance];
    [self buildLabelsWithParameters:p tableCenterZ:centerZ];
    [self setShutterOpen:p.shutterOpen];
    [self updateScreenAppearance];
}

- (SCNMaterial *)metalMaterialWithColor:(NSColor *)color metallic:(CGFloat)metallic roughness:(CGFloat)roughness {
    SCNMaterial *material = [SCNMaterial material];
    material.lightingModelName = SCNLightingModelPhysicallyBased;
    material.diffuse.contents = color;
    material.metalness.contents = @(metallic);
    material.roughness.contents = @(roughness);
    return material;
}

- (SCNNode *)boxNodeWithWidth:(CGFloat)width
                       height:(CGFloat)height
                       length:(CGFloat)length
                     material:(SCNMaterial *)material
                     position:(SCNVector3)position {
    SCNBox *box = [SCNBox boxWithWidth:width height:height length:length chamferRadius:MIN(0.006, MIN(width, MIN(height, length)) * 0.15)];
    box.materials = @[material];
    SCNNode *node = [SCNNode nodeWithGeometry:box];
    node.position = position;
    return node;
}

- (void)addPostAtX:(CGFloat)x z:(CGFloat)z topY:(CGFloat)topY radius:(CGFloat)radius {
    if (topY <= 0.001) {
        return;
    }
    SCNMaterial *material = [self metalMaterialWithColor:[NSColor colorWithSRGBRed:0.24 green:0.27 blue:0.31 alpha:1.0]
                                                metallic:0.75
                                               roughness:0.38];
    SCNCylinder *post = [SCNCylinder cylinderWithRadius:radius height:topY];
    post.radialSegmentCount = 20;
    post.materials = @[material];
    SCNNode *postNode = [SCNNode nodeWithGeometry:post];
    postNode.position = SCNVector3Make(x, topY * 0.5, z);
    [self.worldRoot addChildNode:postNode];

    SCNCylinder *base = [SCNCylinder cylinderWithRadius:radius * 3.0 height:0.014];
    base.radialSegmentCount = 24;
    base.materials = @[material];
    SCNNode *baseNode = [SCNNode nodeWithGeometry:base];
    baseNode.position = SCNVector3Make(x, 0.007, z);
    [self.worldRoot addChildNode:baseNode];
}

- (void)buildTableWithLength:(double)tableLength centerZ:(double)centerZ {
    NSColor *topColor = [NSColor colorWithSRGBRed:0.075 green:0.088 blue:0.108 alpha:1.0];
    SCNMaterial *topMaterial = [self metalMaterialWithColor:topColor metallic:0.28 roughness:0.67];
    SCNNode *top = [self boxNodeWithWidth:1.14
                                   height:0.06
                                   length:tableLength
                                 material:topMaterial
                                 position:SCNVector3Make(0.0, -0.03, centerZ)];
    top.name = @"optical table";
    [self.worldRoot addChildNode:top];

    SCNMaterial *trimMaterial = [self metalMaterialWithColor:[NSColor colorWithSRGBRed:0.13 green:0.15 blue:0.19 alpha:1.0]
                                                    metallic:0.85
                                                   roughness:0.3];
    SCNNode *trim = [self boxNodeWithWidth:1.16
                                    height:0.014
                                    length:tableLength + 0.02
                                  material:trimMaterial
                                  position:SCNVector3Make(0.0, -0.058, centerZ)];
    [self.worldRoot addChildNode:trim];

    SCNMaterial *legMaterial = [self metalMaterialWithColor:[NSColor colorWithSRGBRed:0.16 green:0.18 blue:0.22 alpha:1.0]
                                                   metallic:0.7
                                                  roughness:0.4];
    double legOffset = MAX(0.24, tableLength * 0.5 - 0.24);
    for (NSInteger sx = -1; sx <= 1; sx += 2) {
        for (NSInteger sz = -1; sz <= 1; sz += 2) {
            SCNCylinder *leg = [SCNCylinder cylinderWithRadius:0.035 height:0.65];
            leg.radialSegmentCount = 20;
            leg.materials = @[legMaterial];
            SCNNode *legNode = [SCNNode nodeWithGeometry:leg];
            legNode.position = SCNVector3Make(sx * 0.47, -0.39, centerZ + sz * legOffset);
            [self.worldRoot addChildNode:legNode];
        }
    }

    // Breadboard hole pattern on the tabletop.
    if (!self.breadboardImage) {
        self.breadboardImage = [self makeBreadboardImage];
    }
    SCNMaterial *surface = [SCNMaterial material];
    surface.lightingModelName = SCNLightingModelPhysicallyBased;
    surface.diffuse.contents = self.breadboardImage;
    surface.diffuse.wrapS = SCNWrapModeRepeat;
    surface.diffuse.wrapT = SCNWrapModeRepeat;
    surface.diffuse.contentsTransform = SCNMatrix4MakeScale(5.0, 5.0, 1.0);
    surface.metalness.contents = @0.32;
    surface.roughness.contents = @0.58;
    SCNPlane *surfacePlane = [SCNPlane planeWithWidth:1.13 height:tableLength];
    surfacePlane.materials = @[surface];
    SCNNode *surfaceNode = [SCNNode nodeWithGeometry:surfacePlane];
    surfaceNode.eulerAngles = SCNVector3Make(-M_PI_2, 0.0, 0.0);
    surfaceNode.position = SCNVector3Make(0.0, 0.001, centerZ);
    [self.worldRoot addChildNode:surfaceNode];
}

- (NSImage *)makeBreadboardImage {
    NSSize size = NSMakeSize(256.0, 256.0);
    NSImage *image = [[NSImage alloc] initWithSize:size];
    [image lockFocus];
    [[NSColor colorWithSRGBRed:0.080 green:0.094 blue:0.115 alpha:1.0] setFill];
    NSRectFill(NSMakeRect(0.0, 0.0, size.width, size.height));
    [[NSColor colorWithSRGBRed:0.155 green:0.175 blue:0.205 alpha:0.75] setFill];
    for (NSInteger y = 10; y < 256; y += 20) {
        for (NSInteger x = 10; x < 256; x += 20) {
            NSBezierPath *hole = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect((CGFloat)x - 2.0, (CGFloat)y - 2.0, 4.0, 4.0)];
            [hole fill];
        }
    }
    [image unlockFocus];
    return image;
}

- (void)buildLaserAtZ:(double)z parameters:(DSExperimentParameters *)p {
    SCNNode *group = [SCNNode node];
    group.position = SCNVector3Make(0.0, DSBeamHeight, z);
    group.name = @"laser";
    [self.worldRoot addChildNode:group];

    SCNMaterial *bodyMaterial = [self metalMaterialWithColor:[NSColor colorWithSRGBRed:0.105 green:0.118 blue:0.138 alpha:1.0]
                                                   metallic:0.82
                                                  roughness:0.32];
    SCNMaterial *darkMaterial = [self metalMaterialWithColor:[NSColor colorWithSRGBRed:0.055 green:0.063 blue:0.077 alpha:1.0]
                                                   metallic:0.55
                                                  roughness:0.48];

    SCNCylinder *body = [SCNCylinder cylinderWithRadius:0.066 height:0.36];
    body.radialSegmentCount = 40;
    body.materials = @[bodyMaterial];
    SCNNode *bodyNode = [SCNNode nodeWithGeometry:body];
    bodyNode.eulerAngles = SCNVector3Make(M_PI_2, 0.0, 0.0);
    bodyNode.position = SCNVector3Make(0.0, 0.0, -0.195);
    [group addChildNode:bodyNode];

    for (NSNumber *ringZ in @[@(-0.365), @(-0.30), @(-0.075)]) {
        SCNTorus *ring = [SCNTorus torusWithRingRadius:0.0675 pipeRadius:0.006];
        ring.ringSegmentCount = 48;
        ring.pipeSegmentCount = 12;
        ring.materials = @[darkMaterial];
        SCNNode *ringNode = [SCNNode nodeWithGeometry:ring];
        ringNode.eulerAngles = SCNVector3Make(M_PI_2, 0.0, 0.0);
        ringNode.position = SCNVector3Make(0.0, 0.0, ringZ.doubleValue);
        [group addChildNode:ringNode];
    }

    SCNCylinder *bezel = [SCNCylinder cylinderWithRadius:0.061 height:0.028];
    bezel.radialSegmentCount = 40;
    bezel.materials = @[darkMaterial];
    SCNNode *bezelNode = [SCNNode nodeWithGeometry:bezel];
    bezelNode.eulerAngles = SCNVector3Make(M_PI_2, 0.0, 0.0);
    bezelNode.position = SCNVector3Make(0.0, 0.0, -0.012);
    [group addChildNode:bezelNode];

    SCNMaterial *lensMaterial = [SCNMaterial material];
    lensMaterial.lightingModelName = SCNLightingModelConstant;
    lensMaterial.diffuse.contents = [self.accentColor colorWithAlphaComponent:1.0];
    lensMaterial.emission.contents = [self.accentColor colorWithAlphaComponent:1.0];
    lensMaterial.emission.intensity = 2.4;
    SCNCylinder *lens = [SCNCylinder cylinderWithRadius:0.044 height:0.006];
    lens.radialSegmentCount = 40;
    lens.materials = @[lensMaterial];
    SCNNode *lensNode = [SCNNode nodeWithGeometry:lens];
    lensNode.eulerAngles = SCNVector3Make(M_PI_2, 0.0, 0.0);
    lensNode.position = SCNVector3Make(0.0, 0.0, 0.003);
    lensNode.name = @"laser lens";
    self.laserLensNode = lensNode;
    [group addChildNode:lensNode];

    SCNCylinder *indicator = [SCNCylinder cylinderWithRadius:0.006 height:0.003];
    indicator.radialSegmentCount = 16;
    SCNMaterial *indicatorMaterial = [SCNMaterial material];
    indicatorMaterial.lightingModelName = SCNLightingModelConstant;
    indicatorMaterial.diffuse.contents = [DSTheme liveGreen];
    indicatorMaterial.emission.contents = [DSTheme liveGreen];
    indicatorMaterial.emission.intensity = 2.0;
    indicator.materials = @[indicatorMaterial];
    SCNNode *indicatorNode = [SCNNode nodeWithGeometry:indicator];
    indicatorNode.position = SCNVector3Make(0.0, 0.074, -0.28);
    [group addChildNode:indicatorNode];

    [self addPostAtX:0.0 z:z topY:DSBeamHeight - 0.066 radius:0.018];
}

- (void)buildApertureWithParameters:(DSExperimentParameters *)p {
    SCNNode *group = [SCNNode node];
    group.position = SCNVector3Make(0.0, DSBeamHeight, 0.0);
    group.name = @"aperture";
    [self.worldRoot addChildNode:group];

    double widthFraction = (log(MAX(p.slitWidthUm, 2.0)) - log(2.0)) / (log(200.0) - log(2.0));
    widthFraction = fmin(1.0, fmax(0.0, widthFraction));
    double lengthFraction = (log(MAX(p.slitLengthMm, 0.1)) - log(0.1)) / (log(20.0) - log(0.1));
    lengthFraction = fmin(1.0, fmax(0.0, lengthFraction));
    double pitchFraction = (log(MAX(p.slitPitchUm, 20.0)) - log(20.0)) / (log(2000.0) - log(20.0));
    pitchFraction = fmin(1.0, fmax(0.0, pitchFraction));

    CGFloat gap = 0.0045 + widthFraction * 0.014;
    CGFloat holeHeight = 0.055 + lengthFraction * 0.205;
    CGFloat visualPitch = fmax(gap + 0.011, 0.020 + pitchFraction * 0.038);
    NSUInteger count = MAX((NSUInteger)1, p.slitCount);
    CGFloat arrayWidth = (CGFloat)(count - 1) * visualPitch + gap;
    CGFloat plateWidth = fmax(0.46, arrayWidth + 0.16);
    CGFloat plateHeight = 0.62;
    CGFloat thickness = 0.010;

    SCNMaterial *plateMaterial = [self metalMaterialWithColor:[NSColor colorWithSRGBRed:0.115 green:0.125 blue:0.145 alpha:1.0]
                                                     metallic:0.72
                                                    roughness:0.36];
    SCNMaterial *edgeMaterial = [self metalMaterialWithColor:[NSColor colorWithSRGBRed:0.26 green:0.28 blue:0.32 alpha:1.0]
                                                    metallic:0.9
                                                   roughness:0.22];

    CGFloat sideWidth = (plateWidth - arrayWidth) * 0.5;
    SCNNode *left = [self boxNodeWithWidth:sideWidth height:plateHeight length:thickness material:plateMaterial
                                  position:SCNVector3Make(-(arrayWidth * 0.5 + sideWidth * 0.5), 0.0, 0.0)];
    SCNNode *right = [self boxNodeWithWidth:sideWidth height:plateHeight length:thickness material:plateMaterial
                                   position:SCNVector3Make(arrayWidth * 0.5 + sideWidth * 0.5, 0.0, 0.0)];
    [group addChildNode:left];
    [group addChildNode:right];

    CGFloat fillHeight = (plateHeight - holeHeight) * 0.5;
    SCNNode *top = [self boxNodeWithWidth:arrayWidth height:fillHeight length:thickness material:plateMaterial
                                 position:SCNVector3Make(0.0, holeHeight * 0.5 + fillHeight * 0.5, 0.0)];
    SCNNode *bottom = [self boxNodeWithWidth:arrayWidth height:fillHeight length:thickness material:plateMaterial
                                    position:SCNVector3Make(0.0, -(holeHeight * 0.5 + fillHeight * 0.5), 0.0)];
    [group addChildNode:top];
    [group addChildNode:bottom];

    for (NSUInteger i = 1; i < count; i++) {
        CGFloat separatorWidth = visualPitch - gap;
        CGFloat centerX = -(arrayWidth * 0.5) + gap * 0.5 + (CGFloat)i * visualPitch - gap * 0.5 - separatorWidth * 0.5;
        SCNNode *separator = [self boxNodeWithWidth:separatorWidth
                                             height:holeHeight
                                             length:thickness
                                           material:plateMaterial
                                           position:SCNVector3Make(centerX, 0.0, 0.0)];
        [group addChildNode:separator];
    }

    SCNNode *topTrim = [self boxNodeWithWidth:plateWidth height:0.008 length:thickness + 0.008 material:edgeMaterial
                                     position:SCNVector3Make(0.0, plateHeight * 0.5, 0.0)];
    SCNNode *bottomTrim = [self boxNodeWithWidth:plateWidth height:0.008 length:thickness + 0.008 material:edgeMaterial
                                        position:SCNVector3Make(0.0, -plateHeight * 0.5, 0.0)];
    [group addChildNode:topTrim];
    [group addChildNode:bottomTrim];

    // Illuminate the apertures from behind so the number and shape of the slits
    // remain legible from the camera's oblique viewing angle.
    SCNMaterial *apertureGlowMaterial = [SCNMaterial material];
    apertureGlowMaterial.lightingModelName = SCNLightingModelConstant;
    apertureGlowMaterial.diffuse.contents = self.accentColor;
    apertureGlowMaterial.emission.contents = self.accentColor;
    apertureGlowMaterial.emission.intensity = 1.05;
    apertureGlowMaterial.transparency = 0.66;
    apertureGlowMaterial.doubleSided = YES;
    apertureGlowMaterial.writesToDepthBuffer = NO;
    SCNPlane *apertureGlow = [SCNPlane planeWithWidth:arrayWidth + gap * 0.4
                                              height:holeHeight + 0.012];
    apertureGlow.materials = @[apertureGlowMaterial];
    SCNNode *apertureGlowNode = [SCNNode nodeWithGeometry:apertureGlow];
    apertureGlowNode.position = SCNVector3Make(0.0, 0.0, thickness * 0.5 + 0.003);
    self.apertureGlowNode = apertureGlowNode;
    [group addChildNode:apertureGlowNode];

    // A small emissive pin gives the plate a readable visual anchor.
    SCNMaterial *pinMaterial = [SCNMaterial material];
    pinMaterial.lightingModelName = SCNLightingModelConstant;
    pinMaterial.diffuse.contents = self.accentColor;
    pinMaterial.emission.contents = self.accentColor;
    pinMaterial.emission.intensity = 1.2;
    SCNCylinder *pin = [SCNCylinder cylinderWithRadius:0.005 height:0.004];
    pin.radialSegmentCount = 16;
    pin.materials = @[pinMaterial];
    SCNNode *pinNode = [SCNNode nodeWithGeometry:pin];
    pinNode.eulerAngles = SCNVector3Make(M_PI_2, 0.0, 0.0);
    pinNode.position = SCNVector3Make(0.0, plateHeight * 0.5 + 0.035, 0.002);
    [group addChildNode:pinNode];

    [self addPostAtX:0.0 z:0.0 topY:DSBeamHeight - plateHeight * 0.5 radius:0.018];
}

- (void)buildScreenAtZ:(double)z parameters:(DSExperimentParameters *)p {
    SCNNode *group = [SCNNode node];
    group.position = SCNVector3Make(0.0, DSBeamHeight, z);
    group.name = @"screen";
    [self.worldRoot addChildNode:group];

    SCNMaterial *frameMaterial = [self metalMaterialWithColor:[NSColor colorWithSRGBRed:0.085 green:0.095 blue:0.115 alpha:1.0]
                                                     metallic:0.72
                                                    roughness:0.35];
    SCNNode *frame = [self boxNodeWithWidth:0.98 height:0.62 length:0.022 material:frameMaterial
                                   position:SCNVector3Make(0.0, 0.0, 0.016)];
    [group addChildNode:frame];

    SCNMaterial *screenMaterial = [SCNMaterial material];
    screenMaterial.lightingModelName = SCNLightingModelConstant;
    screenMaterial.diffuse.contents = [NSColor colorWithSRGBRed:0.025 green:0.029 blue:0.036 alpha:1.0];
    screenMaterial.emission.contents = [NSColor blackColor];
    screenMaterial.emission.intensity = 0.0;
    screenMaterial.doubleSided = YES;
    self.screenMaterial = screenMaterial;

    SCNPlane *screenPlane = [SCNPlane planeWithWidth:0.93 height:0.558];
    screenPlane.materials = @[screenMaterial];
    SCNNode *patternNode = [SCNNode nodeWithGeometry:screenPlane];
    patternNode.eulerAngles = SCNVector3Make(0.0, M_PI, 0.0);
    patternNode.position = SCNVector3Make(0.0, 0.0, 0.003);
    patternNode.name = @"screen pattern";
    [group addChildNode:patternNode];

    SCNNode *topTrim = [self boxNodeWithWidth:0.99 height:0.018 length:0.03 material:frameMaterial
                                     position:SCNVector3Make(0.0, 0.31, 0.014)];
    [group addChildNode:topTrim];

    for (NSInteger sign = -1; sign <= 1; sign += 2) {
        [self addPostAtX:sign * 0.33 z:z topY:DSBeamHeight - 0.279 radius:0.016];
    }
}

- (void)buildBeamFromZ:(double)startZ toZ:(double)endZ parameters:(DSExperimentParameters *)p {
    SCNNode *beamGroup = [SCNNode node];
    beamGroup.name = @"beam";
    CGFloat length = MAX(0.01, endZ - startZ);
    CGFloat center = startZ + length * 0.5;

    SCNMaterial *coreMaterial = [SCNMaterial material];
    coreMaterial.lightingModelName = SCNLightingModelConstant;
    coreMaterial.diffuse.contents = [NSColor blackColor];
    coreMaterial.emission.contents = [self.accentColor colorWithAlphaComponent:1.0];
    coreMaterial.emission.intensity = 3.2;
    coreMaterial.writesToDepthBuffer = NO;

    SCNCylinder *core = [SCNCylinder cylinderWithRadius:0.0022 height:length];
    core.radialSegmentCount = 12;
    core.materials = @[coreMaterial];
    SCNNode *coreNode = [SCNNode nodeWithGeometry:core];
    coreNode.eulerAngles = SCNVector3Make(M_PI_2, 0.0, 0.0);
    coreNode.position = SCNVector3Make(0.0, DSBeamHeight, center);
    [beamGroup addChildNode:coreNode];

    SCNMaterial *glowMaterial = [SCNMaterial material];
    glowMaterial.lightingModelName = SCNLightingModelConstant;
    glowMaterial.diffuse.contents = [NSColor blackColor];
    glowMaterial.emission.contents = [self.accentColor colorWithAlphaComponent:1.0];
    glowMaterial.emission.intensity = 1.0;
    glowMaterial.transparency = 0.22;
    glowMaterial.blendMode = SCNBlendModeAdd;
    glowMaterial.writesToDepthBuffer = NO;
    glowMaterial.doubleSided = YES;
    SCNCylinder *glowCylinder = [SCNCylinder cylinderWithRadius:0.008 height:length];
    glowCylinder.radialSegmentCount = 20;
    glowCylinder.materials = @[glowMaterial];
    SCNNode *glowNode = [SCNNode nodeWithGeometry:glowCylinder];
    glowNode.eulerAngles = SCNVector3Make(M_PI_2, 0.0, 0.0);
    glowNode.position = SCNVector3Make(0.0, DSBeamHeight, center);
    [beamGroup addChildNode:glowNode];

    [self.worldRoot addChildNode:beamGroup];
    self.beamGroup = beamGroup;
}

- (void)buildFanToScreenAtZ:(double)screenDistance {
    if (screenDistance <= 0.01) {
        return;
    }
    SCNVector3 apex = SCNVector3Make(0.0, DSBeamHeight, 0.035);
    SCNVector3 base[4] = {
        SCNVector3Make(-0.465, DSBeamHeight - 0.279, screenDistance),
        SCNVector3Make( 0.465, DSBeamHeight - 0.279, screenDistance),
        SCNVector3Make( 0.465, DSBeamHeight + 0.279, screenDistance),
        SCNVector3Make(-0.465, DSBeamHeight + 0.279, screenDistance)
    };
    SCNVector3 points[5] = {apex, base[0], base[1], base[2], base[3]};
    uint16_t indices[12] = {
        0, 1, 2,
        0, 2, 3,
        0, 3, 4,
        0, 4, 1
    };
    NSData *indexData = [NSData dataWithBytes:indices length:sizeof(indices)];
    SCNGeometryElement *element = [SCNGeometryElement geometryElementWithData:indexData
                                                                primitiveType:SCNGeometryPrimitiveTypeTriangles
                                                               primitiveCount:4
                                                                bytesPerIndex:sizeof(uint16_t)];
    SCNGeometrySource *source = [SCNGeometrySource geometrySourceWithVertices:points count:5];
    SCNGeometry *geometry = [SCNGeometry geometryWithSources:@[source] elements:@[element]];
    SCNMaterial *material = [SCNMaterial material];
    material.lightingModelName = SCNLightingModelConstant;
    material.diffuse.contents = [NSColor blackColor];
    material.emission.contents = [self.accentColor colorWithAlphaComponent:1.0];
    material.emission.intensity = 0.42;
    material.transparency = 0.075;
    material.blendMode = SCNBlendModeAlpha;
    material.doubleSided = YES;
    material.writesToDepthBuffer = NO;
    geometry.materials = @[material];
    SCNNode *fan = [SCNNode nodeWithGeometry:geometry];
    fan.name = @"diffraction fan";
    [self.worldRoot addChildNode:fan];
    self.fanNode = fan;
}

- (void)updateScreenAppearance {
    if (!self.screenMaterial) {
        return;
    }
    if (!self.shutterOpen) {
        self.screenMaterial.diffuse.contents = [NSColor colorWithSRGBRed:0.022 green:0.026 blue:0.033 alpha:1.0];
        self.screenMaterial.emission.contents = [NSColor blackColor];
        self.screenMaterial.emission.intensity = 0.0;
        return;
    }
    if (self.patternImage) {
        self.screenMaterial.diffuse.contents = self.patternImage;
        self.screenMaterial.emission.contents = self.patternImage;
        self.screenMaterial.emission.intensity = 0.18;
    } else {
        self.screenMaterial.diffuse.contents = [NSColor colorWithSRGBRed:0.022 green:0.026 blue:0.033 alpha:1.0];
        self.screenMaterial.emission.contents = [NSColor blackColor];
        self.screenMaterial.emission.intensity = 0.0;
    }
}

#pragma mark - Labels

- (SCNNode *)labelNamed:(NSString *)text
                  color:(NSColor *)color
               fontSize:(CGFloat)fontSize
           worldPosition:(SCNVector3)position {
    SCNText *textGeometry = [SCNText textWithString:text extrusionDepth:0.01];
    textGeometry.font = [NSFont monospacedSystemFontOfSize:fontSize weight:NSFontWeightSemibold];
    textGeometry.flatness = 0.25;
    textGeometry.chamferRadius = 0.0;

    SCNMaterial *textMaterial = [SCNMaterial material];
    textMaterial.lightingModelName = SCNLightingModelConstant;
    textMaterial.diffuse.contents = color;
    textMaterial.emission.contents = color;
    textMaterial.emission.intensity = 0.55;
    textMaterial.doubleSided = YES;
    textGeometry.materials = @[textMaterial];

    SCNVector3 min, max;
    [textGeometry getBoundingBoxMin:&min max:&max];
    CGFloat scale = 0.0024;
    CGFloat width = (max.x - min.x) * scale;
    CGFloat height = (max.y - min.y) * scale;

    SCNNode *container = [SCNNode node];
    container.position = position;

    SCNPlane *plate = [SCNPlane planeWithWidth:width + 0.032 height:height + 0.020];
    SCNMaterial *plateMaterial = [SCNMaterial material];
    plateMaterial.lightingModelName = SCNLightingModelConstant;
    plateMaterial.diffuse.contents = [NSColor colorWithSRGBRed:0.015 green:0.023 blue:0.035 alpha:0.88];
    plateMaterial.transparency = 0.82;
    plateMaterial.doubleSided = YES;
    plateMaterial.writesToDepthBuffer = NO;
    plate.materials = @[plateMaterial];
    SCNNode *plateNode = [SCNNode nodeWithGeometry:plate];
    plateNode.position = SCNVector3Make(0.0, 0.0, -0.003);
    plateNode.renderingOrder = 30;
    [container addChildNode:plateNode];

    SCNNode *textNode = [SCNNode nodeWithGeometry:textGeometry];
    textNode.scale = SCNVector3Make(scale, scale, scale);
    textNode.position = SCNVector3Make(-(min.x + max.x) * 0.5 * scale,
                                       -(min.y + max.y) * 0.5 * scale,
                                       0.004);
    textNode.renderingOrder = 31;
    [container addChildNode:textNode];

    SCNBillboardConstraint *billboard = [SCNBillboardConstraint billboardConstraint];
    billboard.freeAxes = SCNBillboardAxisAll;
    container.constraints = @[billboard];
    return container;
}

- (void)buildLabelsWithParameters:(DSExperimentParameters *)p tableCenterZ:(double)tableCenterZ {
    SCNNode *group = [SCNNode node];
    group.name = @"labels";
    [self.worldRoot addChildNode:group];
    self.labelsGroup = group;

    [group addChildNode:[self labelNamed:@"LASER"
                                  color:[DSTheme textPrimary]
                               fontSize:15.0
                           worldPosition:SCNVector3Make(0.0, DSBeamHeight + 0.20, -p.laserDistanceM)]];
    [group addChildNode:[self labelNamed:@"SLIT APERTURE"
                                  color:self.accentColor
                               fontSize:15.0
                           worldPosition:SCNVector3Make(0.0, DSBeamHeight + 0.43, 0.0)]];
    [group addChildNode:[self labelNamed:@"DETECTOR SCREEN"
                                  color:[DSTheme textPrimary]
                               fontSize:15.0
                           worldPosition:SCNVector3Make(0.0, DSBeamHeight + 0.43, p.screenDistanceM)]];

    NSString *sourceDistance = [NSString stringWithFormat:@"%.2f m", p.laserDistanceM];
    NSString *screenDistance = [NSString stringWithFormat:@"%.2f m", p.screenDistanceM];
    [group addChildNode:[self labelNamed:sourceDistance
                                  color:[DSTheme textSecondary]
                               fontSize:11.0
                           worldPosition:SCNVector3Make(0.0, 0.085, -p.laserDistanceM * 0.5)]];
    [group addChildNode:[self labelNamed:screenDistance
                                  color:[DSTheme textSecondary]
                               fontSize:11.0
                           worldPosition:SCNVector3Make(0.0, 0.085, p.screenDistanceM * 0.5)]];

    group.hidden = !self.labelsVisible;
}

#pragma mark - Camera

- (void)fitCameraForLaserDistance:(double)laserDistance screenDistance:(double)screenDistance animated:(BOOL)animated {
    self.sceneView.pointOfView = self.cameraNode;
    self.sceneView.allowsCameraControl = YES;

    SCNCameraController *controller = self.sceneView.defaultCameraController;
    [controller stopInertia];
    
    double span = laserDistance + screenDistance + 0.9;
    double centerZ = (screenDistance - laserDistance) * 0.5;
    SCNVector3 target = SCNVector3Make(0.0, 0.32, centerZ);
    double radius = sqrt((span * 0.5) * (span * 0.5) + 0.65 * 0.65 + 0.5 * 0.5);
    double distance = MAX(2.1, radius / sin(M_PI / 9.0) * 0.86);

    SCNVector3 unit = SCNVector3Make(0.58, 0.36, -0.73);
    SCNVector3 position = SCNVector3Make(target.x + unit.x * distance,
                                         target.y + unit.y * distance,
                                         target.z + unit.z * distance);
    void (^apply)(void) = ^{
        self.cameraNode.position = position;
        [self.cameraNode lookAt:target up:SCNVector3Make(0.0, 1.0, 0.0) localFront:SCNVector3Make(0.0, 0.0, -1.0)];
    };
    if (animated) {
        [SCNTransaction begin];
        [SCNTransaction setAnimationDuration:0.35];
        apply();
        [SCNTransaction setCompletionBlock:^{
            self.sceneView.pointOfView = self.cameraNode;
            self.sceneView.allowsCameraControl = YES;
            self.sceneView.defaultCameraController.target = target;
        }];
        [SCNTransaction commit];
    } else {
        apply();
        self.sceneView.pointOfView = self.cameraNode;
        self.sceneView.allowsCameraControl = YES;
        self.sceneView.defaultCameraController.target = target;
    }
}

@end
