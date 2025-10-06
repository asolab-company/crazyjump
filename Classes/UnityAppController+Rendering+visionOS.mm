#if PLATFORM_VISIONOS

#import <CompositorServices/CompositorServices.h>
#import "UnityAppController+Rendering+visionOS.h"
#import "UnityAppController+Rendering.h"


static cp_layer_renderer_t _LayerRenderer;
static cp_layer_renderer_state _LayerRendererState = cp_layer_renderer_state_running;
static bool _ShouldDispatchRepaint = false;

extern bool _didResignActive;


@implementation UnityAppController (Rendering_visionOS)

- (BOOL)usingCompositorLayer
{
    return _LayerRenderer != nil;
}

- (void)repaintCompositorLayer
{
    // Terminate dispatch loop when the app quits.
    // If _quitHandler is set, we don't call exit() and this loop will continue indefinitely, preventing the app from quitting.
    if (self.engineLoadState == kUnityEngineLoadStateNotStarted)
        return;

    auto isRendererRunning = _LayerRendererState == cp_layer_renderer_state_running;
    auto isAppActive = [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;

    if (isAppActive)
    {
        if (isRendererRunning)
        {
            if (UnityIsPaused())
            {
                UnityWillResume();
                UnityPause(0);
            }

            if(self.engineLoadState >= kUnityEngineLoadStateRenderingInitialized)
            {
                UnityDisplayLinkCallback(0.0);
                [self repaint];
            }
        }
        else
        {
            _LayerRendererState = cp_layer_renderer_get_state(_LayerRenderer);
        }
    }
    else
    {
        if(_didResignActive)
        {
            UnityDisplayLinkCallback(0.0);
            [self repaint];
        }
        else if (!UnityIsPaused())
        {
            if (UnityIsFocused())
                UnitySetPlayerFocus(0);

            UnityPause(1);
        }
        else
        {
            _LayerRendererState = cp_layer_renderer_get_state(_LayerRenderer);
        }
    }

    if (_ShouldDispatchRepaint)
        dispatch_async(dispatch_get_main_queue(), ^{ [self repaintDisplayLink]; });
}

@end


@interface UnityVisionOSCompositorBridge : NSObject

+ (void)setLayerRenderer:(cp_layer_renderer_t)layerRenderer;
+ (void)setLayerRendererState:(NSNumber*)layerRendererState;

@end

@implementation UnityVisionOSCompositorBridge

+ (void)setLayerRenderer:(cp_layer_renderer_t)layerRenderer
{
    _LayerRenderer = layerRenderer;
    if (layerRenderer == nil)
    {
        _ShouldDispatchRepaint = false;
        [_UnityAppController createDisplayLink];
    }
    else
    {
        _ShouldDispatchRepaint = true;
        [_UnityAppController destroyDisplayLink];

        // Manually call repaintDisplayLink to kick off dispatched repaint loop
        [_UnityAppController repaintDisplayLink];
    }
}

+ (void)setLayerRendererState:(NSNumber*) layerRendererStateObject
{
    _LayerRendererState = (cp_layer_renderer_state)layerRendererStateObject.intValue;
}

@end

#endif
