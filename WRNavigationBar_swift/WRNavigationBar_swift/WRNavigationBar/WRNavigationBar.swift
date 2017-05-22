//
//  UINavigationBar+WRAddition.swift
//  WRNavigationBar_swift
//
//  Created by wangrui on 2017/4/19.
//  Copyright © 2017年 wangrui. All rights reserved.
//

import UIKit

extension UINavigationBar
{
    fileprivate struct AssociatedKeys {
        static var backgroundView:UIView = UIView()
    }
    
    /// 设置导航栏背景颜色
    func wr_setBackgroundColor(color:UIColor)
    {
        if (self.backgroundView() == nil)
        {
            // 设置导航栏本身全透明
            self.setBackgroundImage(UIImage(), for: .default)
            self.setBackgroundView(backgroundView: UIView(frame: CGRect(x: 0, y: 0, width: Int(bounds.width), height: 64)))
            // _UIBarBackground是导航栏的第一个子控件
            self.subviews.first?.insertSubview(self.backgroundView() ?? UIView(), at: 0)
            // 隐藏导航栏底部默认黑线
            self.shadowImage = UIImage()
        }
        self.backgroundView()?.backgroundColor = color
    }
    
    /// 设置导航栏所有BarButtonItem的透明度
    func wr_setBarButtonItemsAlpha(alpha:CGFloat, hasSystemBackIndicator:Bool)
    {
        for view in self.subviews
        {
            if (hasSystemBackIndicator == true)
            {
                // _UIBarBackground对应的view是系统导航栏，不需要改变其透明度
                if let _UIBarBackgroundClass = NSClassFromString("_UIBarBackground")
                {
                    if (view.isKind(of: _UIBarBackgroundClass) == false) {
                        view.alpha = alpha
                    }
                }
            }
            else
            {
                // 这里如果不做判断的话，会显示 backIndicatorImage(系统返回按钮)
                if let _UINavigationBarBackIndicatorViewClass = NSClassFromString("_UINavigationBarBackIndicatorView"),
                   let _UIBarBackgroundClass                  = NSClassFromString("_UIBarBackground")
                {
                    if (view.isKind(of: _UINavigationBarBackIndicatorViewClass) == false && view.isKind(of: _UIBarBackgroundClass) == false) {
                        view.alpha = alpha
                    }
                }
            }
        }
    }
    
    /// 设置导航栏在垂直方向上平移多少距离
    func wr_setTranslationY(translationY:CGFloat)
    {
        self.transform = CGAffineTransform.init(translationX: 0, y: translationY)
    }
    
    /// 清除在导航栏上设置的背景颜色、透明度、位移距离等属性
    func wr_clear()
    {
        // 设置导航栏不透明
        self.setBackgroundImage(nil, for: .default)
        self.backgroundView()?.removeFromSuperview()
        self.setBackgroundView(backgroundView: nil)
    }
    
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // private func
    func backgroundView() -> UIView?
    {
        return objc_getAssociatedObject(self, &AssociatedKeys.backgroundView) as? UIView
    }
    
    func setBackgroundView(backgroundView:UIView?)
    {
        objc_setAssociatedObject(self, &AssociatedKeys.backgroundView, backgroundView, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

//==========================================================================
// MARK: - UINavigationController
//==========================================================================
extension UINavigationController
{
    override open var preferredStatusBarStyle: UIStatusBarStyle {
        return topViewController?.preferredStatusBarStyle ?? .default
    }
    
    // call swizzling methods active 主动调用交换方法
    private static let onceToken = UUID().uuidString
    open override class func initialize()
    {
        guard self == UINavigationController.self else { return }
        DispatchQueue.once(token: onceToken)
        {
            let needSwizzleSelectorArr = [
                NSSelectorFromString("_updateInteractiveTransition:"),
                #selector(popToViewController),
                #selector(popToRootViewController),
                #selector(pushViewController)
            ]
            
            for selector in needSwizzleSelectorArr {
                // _updateInteractiveTransition:  =>  wr_updateInteractiveTransition:
                let str = ("wr_" + selector.description).replacingOccurrences(of: "__", with: "_")
                let originalMethod = class_getInstanceMethod(self, selector)
                let swizzledMethod = class_getInstanceMethod(self, Selector(str))
                method_exchangeImplementations(originalMethod, swizzledMethod)
            }
        }
    }
    
    // swizzling system method: updateInteractiveTransition
    func wr_updateInteractiveTransition(_ percentComplete: CGFloat)
    {
        guard let topViewController = topViewController,
              let coordinator       = topViewController.transitionCoordinator else {
                wr_updateInteractiveTransition(percentComplete)
            return
        }
        
        let fromVC = coordinator.viewController(forKey: .from)
        let toVC = coordinator.viewController(forKey: .to)
        
        // change navBarBgColor
        let fromBarTintColor = fromVC?.navBarBarTintColor ?? .defaultNavBarBarTintColor
        let toBarTintColor = toVC?.navBarBarTintColor ?? .defaultNavBarBarTintColor
        let newBarTintColor = middleColor(fromColor: fromBarTintColor, toColor: toBarTintColor, percent: percentComplete)
        setNeedsNavigationBarUpdate(barTintColor: newBarTintColor)
        
        // change navBarTintColor
        let fromTintColor = fromVC?.navBarTintColor ?? .defaultNavBarTintColor
        let toTintColor = toVC?.navBarTintColor ?? .defaultNavBarTintColor
        let newTintColor = middleColor(fromColor: fromTintColor, toColor: toTintColor, percent: percentComplete)
        navigationBar.tintColor = newTintColor
        
        wr_updateInteractiveTransition(percentComplete)
    }
    
    // Calculate the middle Color with translation percent
    private func middleColor(fromColor: UIColor, toColor: UIColor, percent: CGFloat) -> UIColor
    {
        // get current color RGBA
        var fromRed: CGFloat = 0
        var fromGreen: CGFloat = 0
        var fromBlue: CGFloat = 0
        var fromAlpha: CGFloat = 0
        fromColor.getRed(&fromRed, green: &fromGreen, blue: &fromBlue, alpha: &fromAlpha)
        
        // get to color RGBA
        var toRed: CGFloat = 0
        var toGreen: CGFloat = 0
        var toBlue: CGFloat = 0
        var toAlpha: CGFloat = 0
        toColor.getRed(&toRed, green: &toGreen, blue: &toBlue, alpha: &toAlpha)
        
        // calculate middle color RGBA
        let nowRed = fromRed + (toRed - fromRed) * percent
        let nowGreen = fromGreen + (toGreen - fromGreen) * percent
        let nowBlue = fromBlue + (toBlue - fromBlue) * percent
        let nowAlpha = fromAlpha + (toAlpha - fromAlpha) * percent
        return UIColor(red: nowRed, green: nowGreen, blue: nowBlue, alpha: nowAlpha)
    }
    
    struct popProperties {
        fileprivate static let popDuration = 0.13
        fileprivate static var displayCount = 0
        fileprivate static var popProgress:CGFloat {
            let all:CGFloat = CGFloat(60.0 * popDuration)
            let current = min(all, CGFloat(displayCount))
            return current / all
        }
    }
    
    // swizzling system method: popToViewController
    func wr_popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]?
    {
        var displayLink:CADisplayLink? = CADisplayLink(target: self, selector: #selector(popNeedDisplay))
        displayLink?.add(to: RunLoop.main, forMode: .defaultRunLoopMode)
        CATransaction.setCompletionBlock { 
            displayLink?.invalidate()
            displayLink = nil
            popProperties.displayCount = 0
        }
        CATransaction.setAnimationDuration(popProperties.popDuration)
        CATransaction.begin()
        let vcs = wr_popToViewController(viewController, animated: animated)
        CATransaction.commit()
        return vcs
    }
    
    // swizzling system method: popToRootViewControllerAnimated
    func wr_popToRootViewControllerAnimated(_ animated: Bool) -> [UIViewController]?
    {
        var displayLink:CADisplayLink? = CADisplayLink(target: self, selector: #selector(popNeedDisplay))
        displayLink?.add(to: RunLoop.main, forMode: .defaultRunLoopMode)
        CATransaction.setCompletionBlock {
            displayLink?.invalidate()
            displayLink = nil
            popProperties.displayCount = 0
        }
        CATransaction.setAnimationDuration(popProperties.popDuration)
        CATransaction.begin()
        let vcs = wr_popToRootViewControllerAnimated(animated)
        CATransaction.commit()
        return vcs;
        
//        setNeedsNavigationBarUpdate(barTintColor: viewControllers.first?.navBarBarTintColor ?? .defaultNavBarBarTintColor)
//        navigationBar.tintColor = viewControllers.first?.navBarTintColor
//        return
    }
    
    // swizzling system method: pushViewController
    func wr_pushViewController(_ viewController: UIViewController, animated: Bool)
    {
        var displayLink:CADisplayLink? = CADisplayLink(target: self, selector: #selector(pushNeedDisplay))
        displayLink?.add(to: RunLoop.main, forMode: .defaultRunLoopMode)
        CATransaction.setCompletionBlock {
            displayLink?.invalidate()
            displayLink = nil
            pushProperties.displayCount = 0
            viewController.pushToCurrentVCFinished = true
        };
        CATransaction.setAnimationDuration(pushProperties.pushDuration)
        CATransaction.begin()
        wr_pushViewController(viewController, animated: animated)
        CATransaction.commit()
    }
    
    struct pushProperties {
        fileprivate static let pushDuration = 0.13
        fileprivate static var displayCount = 0
        fileprivate static var pushProgress:CGFloat {
            let all:CGFloat = CGFloat(60.0 * pushDuration)
            let current = min(all, CGFloat(displayCount))
            return current / all
        }
    }
    
    // change navigationBar barTintColor smooth before push to current VC finished or before pop to current VC finished
    func pushNeedDisplay()
    {
        guard let topViewController = topViewController,
              let coordinator       = topViewController.transitionCoordinator else {
                // set rootVC navBarBarTintColor and navBarTintColor
                setNeedsNavigationBarUpdate(barTintColor: navBarBarTintColor)
                navigationBar.tintColor = navBarTintColor
                return
        }
        
        pushProperties.displayCount += 1
        let pushProgress = pushProperties.pushProgress
        print("第\(pushProperties.displayCount)次push的进度：\(pushProgress)")
        let fromViewController = coordinator.viewController(forKey: .from)
        let toViewController = coordinator.viewController(forKey: .to)
        
        // change navBarBarTintColor
        let fromBarTintColor = fromViewController?.navBarBarTintColor ?? .defaultNavBarBarTintColor
        let toBarTintColor   = toViewController?.navBarBarTintColor ?? .defaultNavBarBarTintColor
        let newBarTintColor  = middleColor(fromColor: fromBarTintColor, toColor: toBarTintColor, percent: pushProgress)
        setNeedsNavigationBarUpdate(barTintColor: newBarTintColor)
        // change navBarTintColor
        navigationBar.tintColor = toViewController?.navBarTintColor
    }
    
    // change navigationBar barTintColor smooth before pop to current VC finished
    func popNeedDisplay()
    {
        guard let topViewController = topViewController,
            let coordinator       = topViewController.transitionCoordinator else {
                // set rootVC navBarBarTintColor and navBarTintColor
                setNeedsNavigationBarUpdate(barTintColor: navBarBarTintColor)
                navigationBar.tintColor = navBarTintColor
                return
        }
        
        popProperties.displayCount += 1
        let popProgress = popProperties.popProgress
        // print("第\(popProperties.displayCount)次pop的进度：\(popProgress)")
        let fromViewController = coordinator.viewController(forKey: .from)
        let toViewController = coordinator.viewController(forKey: .to)
        
        // change navBarBarTintColor
        let fromBarTintColor = fromViewController?.navBarBarTintColor ?? .defaultNavBarBarTintColor
        let toBarTintColor   = toViewController?.navBarBarTintColor ?? .defaultNavBarBarTintColor
        let newBarTintColor  = middleColor(fromColor: fromBarTintColor, toColor: toBarTintColor, percent: popProgress)
        setNeedsNavigationBarUpdate(barTintColor: newBarTintColor)
        // change navBarTintColor
        navigationBar.tintColor = toViewController?.navBarTintColor
    }
    
    fileprivate func setNeedsNavigationBarUpdate(barTintColor: UIColor) {
        navigationBar.wr_setBackgroundColor(color: barTintColor)
    }
}

//==========================================================================
// MARK: - UINavigationBarDelegate
//==========================================================================
extension UINavigationController: UINavigationBarDelegate
{
    public func navigationBar(_ navigationBar: UINavigationBar, shouldPop item: UINavigationItem) -> Bool
    {
        if let topVC = topViewController,
           let coor = topVC.transitionCoordinator, coor.initiallyInteractive {
            //添加对返回交互的监控
            if #available(iOS 10.0, *) {
                coor.notifyWhenInteractionChanges({ (context) in
                    self.dealInteractionChanges(context)
                })
            } else {
                coor.notifyWhenInteractionEnds({ (context) in
                    self.dealInteractionChanges(context)
                })
            }
            return true
        }
        
        let itemCount = navigationBar.items?.count ?? 0
        let n = viewControllers.count >= itemCount ? 2 : 1
        let popToVC = viewControllers[viewControllers.count - n]
        
        popToViewController(popToVC, animated: true)
        return true
    }
    
    //处理返回手势中断的情况
    private func dealInteractionChanges(_ context: UIViewControllerTransitionCoordinatorContext)
    {
        let animations: (UITransitionContextViewControllerKey) -> () = {
            let curColor = context.viewController(forKey: $0)?.navBarBarTintColor ?? UIColor.defaultNavBarBarTintColor
            self.setNeedsNavigationBarUpdate(barTintColor: curColor)
        }
        
        //自动取消了返回手势
        if context.isCancelled
        {
            let cancelDuration: TimeInterval = context.transitionDuration * Double(context.percentComplete)
            UIView.animate(withDuration: cancelDuration) {
                animations(.from)
            }
        }
        else
        {
            //自动完成了返回手势
            let finishDuration: TimeInterval = context.transitionDuration * Double(1 - context.percentComplete)
            UIView.animate(withDuration: finishDuration) {
                animations(.to)
            }
        }
    }
}

//=============================================================================
// MARK: - store navigationBar barTintColor and tintColor every viewController
//=============================================================================
extension UIViewController
{
    fileprivate struct AssociatedKeys
    {
        static var pushToCurrentVCFinished: Bool = false
        static var pushToNextVCFinished:Bool = false
        static var navBarBarTintColor: UIColor = UIColor.defaultNavBarBarTintColor
        static var navBarTintColor: UIColor = UIColor.defaultNavBarTintColor
    }
    
    // navigationBar barTintColor can change by current VC when fromVC push finished
    var pushToCurrentVCFinished:Bool {
        get {
            guard let isFinished = objc_getAssociatedObject(self, &AssociatedKeys.pushToCurrentVCFinished) as? Bool else {
                return false
            }
            return isFinished
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.pushToCurrentVCFinished, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    // navigationBar barTintColor cannot change by current VC when push finished
    var pushToNextVCFinished:Bool {
        get {
            guard let isFinished = objc_getAssociatedObject(self, &AssociatedKeys.pushToNextVCFinished) as? Bool else {
                return false
            }
            return isFinished
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.pushToNextVCFinished, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    // navigationBar barTintColor
    var navBarBarTintColor: UIColor {
        get {
            guard let barTintColor = objc_getAssociatedObject(self, &AssociatedKeys.navBarBarTintColor) as? UIColor else {
                return UIColor.defaultNavBarBarTintColor
            }
            return barTintColor
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.navBarBarTintColor, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            if pushToCurrentVCFinished == true && pushToNextVCFinished == false {
                navigationController?.setNeedsNavigationBarUpdate(barTintColor: newValue)
            }
        }
    }
    
    // navigationBar tintColor
    var navBarTintColor: UIColor {
        get {
            guard let tintColor = objc_getAssociatedObject(self, &AssociatedKeys.navBarTintColor) as? UIColor else {
                return UIColor.defaultNavBarTintColor
            }
            return tintColor
            
        }
        set {
            navigationController?.navigationBar.tintColor = newValue
            objc_setAssociatedObject(self, &AssociatedKeys.navBarTintColor, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // swizzling two system methods: viewWillAppear(_:) and viewWillDisappear(_:)
    private static let onceToken = UUID().uuidString
    open override class func initialize()
    {
        guard self == UIViewController.self else {
            return
        }
        
        DispatchQueue.once(token: onceToken)
        {
            let needSwizzleSelectors = [
                #selector(viewWillAppear(_:)),
                #selector(viewWillDisappear(_:)),
                #selector(viewDidAppear(_:))
            ]
            
            for selector in needSwizzleSelectors
            {
                let newSelectorStr = "wr_" + selector.description
                let originalMethod = class_getInstanceMethod(self, selector)
                let swizzledMethod = class_getInstanceMethod(self, Selector(newSelectorStr))
                method_exchangeImplementations(originalMethod, swizzledMethod)
            }
        }
    }
    
    func wr_viewWillAppear(_ animated: Bool)
    {
        pushToNextVCFinished = false
        wr_viewWillAppear(animated)
    }
    
    func wr_viewWillDisappear(_ animated: Bool)
    {
        pushToNextVCFinished = true
        wr_viewWillDisappear(animated)
    }
    
    func wr_viewDidAppear(_ animated: Bool)
    {
        navigationController?.setNeedsNavigationBarUpdate(barTintColor: navBarBarTintColor)
        wr_viewDidAppear(animated)
    }
}

//====================================================================================
// MARK: - Swizzling会改变全局状态,所以用 DispatchQueue.once 来确保无论多少线程都只会被执行一次
//====================================================================================
extension DispatchQueue {
    
    private static var onceTracker = [String]()
    
    //Executes a block of code, associated with a unique token, only once.  The code is thread safe and will only execute the code once even in the presence of multithreaded calls.
    public class func once(token: String, block: () -> Void)
    {   // 保证被 objc_sync_enter 和 objc_sync_exit 包裹的代码可以有序同步地执行
        objc_sync_enter(self)
        defer { // 作用域结束后执行defer中的代码
            objc_sync_exit(self)
        }
        
        if onceTracker.contains(token) {
            return
        }
        
        onceTracker.append(token)
        block()
    }
}


//==========================================================================
// MARK: - default navigationBar barTintColor and tintColor
//==========================================================================
extension UIColor
{
    class var defaultNavBarBarTintColor: UIColor {
        return UIColor.init(red: 0/255.0, green: 175/255.0, blue: 240/255.0, alpha: 1)
    }
    class var defaultNavBarTintColor: UIColor {
        return UIColor.white
    }
}