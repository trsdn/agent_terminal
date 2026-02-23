import Foundation

protocol TerminalProcess: AnyObject {
    var shellPid: pid_t? { get }
}
