//
//  ViewController.m
//  3DSP1
//
//  Created by kuwaharg on 7/30/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//



#import "ViewController.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))
#define AccelerometerSampleFrequency    50.0 // Hz
#define CMSampleFrequency               50.0 // Hz
#define HPFilterFactor                  0.8
#define Gs                              9.80665 // m/s^2 acceleration due to gravity in SI


#define SharedAccel                     0
#define DebugEulerAngles                0
#define DebugQuat                       0
#define DebugUserAccel                  0

// Uniform index.
enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_NORMAL_MATRIX,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_NORMAL,
    NUM_ATTRIBUTES
};

GLfloat gCubeVertexData[216] = 
{
    // Data layout for each line below is:
    // positionX, positionY, positionZ,     normalX, normalY, normalZ,
    0.5f, -0.5f, -0.5f,        1.0f, 0.0f, 0.0f,
    0.5f, 0.5f, -0.5f,         1.0f, 0.0f, 0.0f,
    0.5f, -0.5f, 0.5f,         1.0f, 0.0f, 0.0f,
    0.5f, -0.5f, 0.5f,         1.0f, 0.0f, 0.0f,
    0.5f, 0.5f, 0.5f,          1.0f, 0.0f, 0.0f,
    0.5f, 0.5f, -0.5f,         1.0f, 0.0f, 0.0f,
    
    0.5f, 0.5f, -0.5f,         0.0f, 1.0f, 0.0f,
    -0.5f, 0.5f, -0.5f,        0.0f, 1.0f, 0.0f,
    0.5f, 0.5f, 0.5f,          0.0f, 1.0f, 0.0f,
    0.5f, 0.5f, 0.5f,          0.0f, 1.0f, 0.0f,
    -0.5f, 0.5f, -0.5f,        0.0f, 1.0f, 0.0f,
    -0.5f, 0.5f, 0.5f,         0.0f, 1.0f, 0.0f,
    
    -0.5f, 0.5f, -0.5f,        -1.0f, 0.0f, 0.0f,
    -0.5f, -0.5f, -0.5f,       -1.0f, 0.0f, 0.0f,
    -0.5f, 0.5f, 0.5f,         -1.0f, 0.0f, 0.0f,
    -0.5f, 0.5f, 0.5f,         -1.0f, 0.0f, 0.0f,
    -0.5f, -0.5f, -0.5f,       -1.0f, 0.0f, 0.0f,
    -0.5f, -0.5f, 0.5f,        -1.0f, 0.0f, 0.0f,
    
    -0.5f, -0.5f, -0.5f,       0.0f, -1.0f, 0.0f,
    0.5f, -0.5f, -0.5f,        0.0f, -1.0f, 0.0f,
    -0.5f, -0.5f, 0.5f,        0.0f, -1.0f, 0.0f,
    -0.5f, -0.5f, 0.5f,        0.0f, -1.0f, 0.0f,
    0.5f, -0.5f, -0.5f,        0.0f, -1.0f, 0.0f,
    0.5f, -0.5f, 0.5f,         0.0f, -1.0f, 0.0f,
    
    0.5f, 0.5f, 0.5f,          0.0f, 0.0f, 1.0f,
    -0.5f, 0.5f, 0.5f,         0.0f, 0.0f, 1.0f,
    0.5f, -0.5f, 0.5f,         0.0f, 0.0f, 1.0f,
    0.5f, -0.5f, 0.5f,         0.0f, 0.0f, 1.0f,
    -0.5f, 0.5f, 0.5f,         0.0f, 0.0f, 1.0f,
    -0.5f, -0.5f, 0.5f,        0.0f, 0.0f, 1.0f,
    
    0.5f, -0.5f, -0.5f,        0.0f, 0.0f, -1.0f,
    -0.5f, -0.5f, -0.5f,       0.0f, 0.0f, -1.0f,
    0.5f, 0.5f, -0.5f,         0.0f, 0.0f, -1.0f,
    0.5f, 0.5f, -0.5f,         0.0f, 0.0f, -1.0f,
    -0.5f, -0.5f, -0.5f,       0.0f, 0.0f, -1.0f,
    -0.5f, 0.5f, -0.5f,        0.0f, 0.0f, -1.0f
};

@interface ViewController () {
    GLuint _program;
    
    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix3 _normalMatrix;
    float _rotation;
    
    GLuint _vertexArray;
    GLuint _vertexBuffer;
    
    // Core Motion objects
    CMMotionManager * sensorManager;
    CMAttitude * startAttitude;
    
    // Shared accelerometer data
    float prevAccelX;
    float prevAccelY;
    float prevAccelZ;
    
    // Sensor fusion accelerometer data
    double x_pos, y_pos, z_pos;
    double x_vel, y_vel, z_vel;
    
    // Transformation matrices
    GLKMatrix4 cmRotate_modelViewMatrix;
    GLKMatrix4 cmTranslate_modelViewMatrix;
    //GLKMatrix4 baseModelViewMatrix;
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;

- (void) enableDeviceMotionSensors;
- (CMMotionManager *) motionManager;
- (void)logToScreenAndConsole:(NSString*)text;

float HiPassFilter (float, float);

@end

@implementation ViewController

// Label Variables
@synthesize x;
@synthesize y;
@synthesize z;
@synthesize logOutput;
@synthesize resetButton;

@synthesize context = _context;
@synthesize effect = _effect;

- (void)viewDidLoad
{
    
#if SharedAccel
    // Accelerometer
    [self logToScreenAndConsole: @"Initializing singleton accelerometer"];
    UIAccelerometer *accel = [UIAccelerometer sharedAccelerometer];
    accel.delegate = self;
    accel.updateInterval = 1.0f/AccelerometerSampleFrequency;

#else
    // Motion Manager
    NSLog(@"Initializing CMMotionManager");
    sensorManager = [self motionManager];
    
    if ( ![sensorManager isAccelerometerAvailable] ){
        [self logToScreenAndConsole:@"Device does not have an available accelerometer. Application cannot proceed."];
    }    
    if ( ![sensorManager isGyroAvailable] ){
        [self logToScreenAndConsole:@"Device does not have an available gyroscope. Application cannot proceed."];
    }
    
    [self enableDeviceMotionSensors];
    
#endif
    
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!self.context) {
        [self logToScreenAndConsole:@"Failed to create ES context"];
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [self setupGL];
    
    //Connect UI buttons
    [resetButton addTarget:self action:@selector(resetView) forControlEvents:UIControlEventTouchUpInside];
    
    //initialize the baseModelViewMatrix
    //baseModelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -4.0f);
    
    [self logToScreenAndConsole:@"viewDidLoad complete"];
}

- (void)viewDidUnload
{    
    [super viewDidUnload];
    
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
	self.context = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc. that aren't in use.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // The application should always stay locked in portrait mode.
    if (UIInterfaceOrientationPortrait == interfaceOrientation){
        return YES;
    } else return NO;
    
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    [self loadShaders];
    
    self.effect = [[GLKBaseEffect alloc] init];
    self.effect.light0.enabled = GL_TRUE;
    self.effect.light0.diffuseColor = GLKVector4Make(1.0f, 0.4f, 0.4f, 1.0f);
    
    glEnable(GL_DEPTH_TEST);
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(gCubeVertexData), gCubeVertexData, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 24, BUFFER_OFFSET(0));
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 24, BUFFER_OFFSET(12));
    
    glBindVertexArrayOES(0);
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteVertexArraysOES(1, &_vertexArray);
    
    self.effect = nil;
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}


- (CMMotionManager *)motionManager
{
    static CMMotionManager *mm = nil;
    
    if (!sensorManager){
        mm = [[CMMotionManager alloc] init];
        return mm;
    }
    else
        return sensorManager;
}

#pragma mark - Motion Data

// Accelerometer data
float HiPassFilter (float currentVal, float previousVal) {
    
    // Subtract the low-pass value from the current value to get a simplified high-pass filter
    
    return currentVal - ( (currentVal * HPFilterFactor) + (previousVal * (1.0 - HPFilterFactor)) );
}


// sharedAccelerometer implementation - turn off if using CoreMotion
#if SharedAccel

- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration
{    
    x.text = [NSString stringWithFormat:@"X is: %f", prevAccelX];
    y.text = [NSString stringWithFormat:@"Y is: %f", prevAccelY];
    z.text = [NSString stringWithFormat:@"Z is: %f", prevAccelZ];
    
    prevAccelX = HiPassFilter(acceleration.x, prevAccelX);
    prevAccelY = HiPassFilter(acceleration.y, prevAccelY);
    prevAccelZ = HiPassFilter((acceleration.z + 1.0), prevAccelZ);
    
    //This assumes +Z = down in real-space
    cmTranslate_modelViewMatrix = GLKMatrix4MakeTranslation(prevAccelX, prevAccelY, prevAccelZ);
}

#else
- (void) enableDeviceMotionSensors
{
    if ( ![sensorManager isDeviceMotionActive] ) {
        
        [sensorManager setDeviceMotionUpdateInterval: 1.0f/CMSampleFrequency ];
        
        // CMAttitudeReferenceFrame is a predefined enum:
        // CMAttitudeReferenceFrameXArbitraryZVertical - Z axis oriented vertically, as on a table.
        // CMAttitudeReferenceFrameXArbitraryCorrectedZVertical - Uses magnetometer to correct yaw and results in increased CPU usage
        
        // Currently rolling a new queue to handle device motion updates. Not really sure if there's a better technique for this.
        [sensorManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryCorrectedZVertical toQueue: [[NSOperationQueue alloc] init] withHandler: ^(CMDeviceMotion *dmReceived, NSError *error)
        {
            
            CMQuaternion currentAttitude_CM = dmReceived.attitude.quaternion;
            double x_posNext, y_posNext, z_posNext;
            double x_velNext, y_velNext, z_velNext;

            // multiplying out Gs to get m/s^2
            double currentAccelerationX = (dmReceived.userAcceleration.x) * Gs;
            double currentAccelerationY = (dmReceived.userAcceleration.y) * Gs;
            double currentAccelerationZ = (dmReceived.userAcceleration.z) * Gs;
            
            // ROTATION
            // We negate the Z rotation in order to simulate a lens
            GLKQuaternion currentAttitude_raw = GLKQuaternionMake( -currentAttitude_CM.x, -currentAttitude_CM.y, -currentAttitude_CM.z, currentAttitude_CM.w);
            GLKQuaternionNormalize( currentAttitude_raw );
            cmRotate_modelViewMatrix = GLKMatrix4MakeWithQuaternion(currentAttitude_raw);
            
            // TRANSLATION
            // We assume constant acceleration over the sampling interval
            //
            //          t_n                  t_n+1                t_n+2
            //  --------|--------------------|--------------------|---------
            //          x_pos                x_posNext
            //          x_vel                x_velNext
            
            x_posNext = x_pos + (x_vel * (1.0/CMSampleFrequency)) + (.5 * currentAccelerationX * pow(1.0/CMSampleFrequency,2));
            y_posNext = y_pos + (y_vel * (1.0/CMSampleFrequency)) + (.5 * currentAccelerationY * pow(1.0/CMSampleFrequency,2));
            z_posNext = z_pos + (z_vel * (1.0/CMSampleFrequency)) + (.5 * currentAccelerationZ * pow(1.0/CMSampleFrequency,2));
            
            x_velNext = x_vel + (currentAccelerationX * (1.0/CMSampleFrequency));
            y_velNext = y_vel + (currentAccelerationY * (1.0/CMSampleFrequency));
            z_velNext = z_vel + (currentAccelerationZ * (1.0/CMSampleFrequency));
            
            // We negate the direction of the vector to simulate a lens
            cmTranslate_modelViewMatrix = GLKMatrix4MakeTranslation( x_posNext, y_posNext, z_posNext );
            
            x_pos = x_posNext;
            y_pos = y_posNext;
            z_pos = z_posNext;
            
            x_vel = x_velNext;
            y_vel = y_velNext;
            z_vel = z_velNext;
            
            // ----------------------------------- LOGGING DEVICE DATA TO SCREEN ------------------------------ //
            
            // Euler Angles
#if DebugEulerAngles
            NSString * pitch = [[NSString alloc] initWithFormat: @"Pitch : %.2f ", dmReceived.attitude.pitch ];
            NSString * roll = [[NSString alloc] initWithFormat: @"Roll : %.2f ", dmReceived.attitude.roll ];
            NSString * yaw = [[NSString alloc] initWithFormat: @"Yaw : %.2f ", dmReceived.attitude.yaw ];
            
            NSString * combineAll = [pitch stringByAppendingString: [roll stringByAppendingString: yaw] ];
            [self logToScreenAndConsole:combineAll];
#endif
            
            // Quaternion
#if DebugQuat
            NSString * quaternionScalar = [[NSString alloc] initWithFormat: @"Scalar : %.2f ", dmReceived.attitude.quaternion.w ];
            NSString * quaternionVX = [[NSString alloc] initWithFormat: @"VX : %.2f ", dmReceived.attitude.quaternion.x ];
            NSString * quaternionVY = [[NSString alloc] initWithFormat: @"VY : %.2f ", dmReceived.attitude.quaternion.y ];
            NSString * quaternionVZ = [[NSString alloc] initWithFormat: @"VZ : %.2f ", dmReceived.attitude.quaternion.z ];
            
            NSString * combineQuat = [quaternionScalar stringByAppendingString: [quaternionVX stringByAppendingString:[ quaternionVY stringByAppendingString:quaternionVZ]]];
            [self logToScreenAndConsole:combineQuat];
#endif
            
            // User Acceleration
#if DebugUserAccel
            NSString * xAccel = [[NSString alloc] initWithFormat: @"X Acceleration : %.2f ", dmReceived.userAcceleration.x ];
            NSString * yAccel = [[NSString alloc] initWithFormat: @"Y Acceleration : %.2f ", dmReceived.userAcceleration.y ];
            NSString * zAccel = [[NSString alloc] initWithFormat: @"Z Acceleration : %.2f ", dmReceived.userAcceleration.z ];
            
            NSString * combineUserAccel = [xAccel stringByAppendingString: [yAccel stringByAppendingString: zAccel] ];
            [self logToScreenAndConsole:combineUserAccel];
#endif
        }
         ];
    }
    
}

#endif


#pragma mark - Helper functions and UI components

- (void)resetView{
    NSLog(@"Resetting view...");
    
    prevAccelX = 0.0;
    prevAccelY = 0.0;
    prevAccelZ = 0.0;
    //baseModelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -4.0f);
    cmTranslate_modelViewMatrix = GLKMatrix4Identity;
    cmRotate_modelViewMatrix = GLKMatrix4Identity;
    
    x_pos = y_pos = z_pos = 0.0;
    x_vel = y_vel = z_vel = 0.0;
    
    if ([sensorManager isDeviceMotionActive]){
        [sensorManager stopDeviceMotionUpdates];
    }
    
    [self enableDeviceMotionSensors];
}

- (void)logToScreenAndConsole:(NSString *) text {
    [logOutput setText:text];
    NSLog(text);
}



#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4Identity;
    
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    
    self.effect.transform.projectionMatrix = projectionMatrix;
    
    baseModelViewMatrix = GLKMatrix4Rotate(baseModelViewMatrix, _rotation, 0.0f, 1.0f, 0.0f);
    
    //Multiply by motion control matrices
    baseModelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, cmRotate_modelViewMatrix);
    baseModelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, cmTranslate_modelViewMatrix);
    
    // Compute the model view matrix for the object rendered with GLKit
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -1.5f);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _rotation, 1.0f, 1.0f, 1.0f);
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
    
    self.effect.transform.modelviewMatrix = modelViewMatrix;
    
    // Compute the model view matrix for the object rendered with ES2
    modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, 1.5f);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _rotation, 1.0f, 1.0f, 1.0f);
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
    
    _normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
    
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    
    //_rotation += self.timeSinceLastUpdate * 0.5f;
    //_rotation = 0.0f;
    
    // FIX THIS HACK ASAP
    //baseModelViewMatrix = GLKMatrix4Identity;
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glBindVertexArrayOES(_vertexArray);
    
    // Render the object with GLKit
    [self.effect prepareToDraw];
    
    glDrawArrays(GL_TRIANGLES, 0, 36);
    
    // Render the object again with ES2
    glUseProgram(_program);
    
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _normalMatrix.m);
    
    glDrawArrays(GL_TRIANGLES, 0, 36);
}

#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(_program, ATTRIB_VERTEX, "position");
    glBindAttribLocation(_program, ATTRIB_NORMAL, "normal");
    
    // Link program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    // Get uniform locations.
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(_program, "normalMatrix");
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

@end
