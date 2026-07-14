import Foundation

public enum StatusLabelMapper {
    public static func label(forToolName toolName: String?) -> String {
        switch toolName ?? "" {
        case "exec_command", "command/exec", "process/spawn":
            return "Running command"
        case "write_stdin":
            return "Sending input"
        case "apply_patch", "fs/writeFile", "fs/remove", "fs/copy":
            return "Editing"
        case "read_mcp_resource", "fs/readFile", "fs/readDirectory":
            return "Reading"
        case "web_search", "web_search_call", "WebSearch":
            return "Searching web"
        case "tool_search_tool", "tool_search_call":
            return "Searching tools"
        case "rg", "find":
            return "Searching files"
        case "imagegen", "image_gen":
            return "Creating image"
        case "view_image", "screenshot":
            return "Viewing image"
        case "js", "js_reset", "js_add_node_module_dir":
            return "Running JS"
        case "update_plan":
            return "Planning"
        case "get_goal":
            return "Checking goal"
        case "create_goal", "update_goal":
            return "Updating goal"
        case "get_app_state", "click", "press_key", "drag", "perform_secondary_action":
            return "Using app"
        case "_search_emails", "_read_email_thread", "_batch_read_email", "_read_email", "_search_email_ids":
            return "Reading email"
        case "_execute_sql", "_read_data_schema", "_read_data_warehouse_schema", "_query_error_tracking_issues_list":
            return "Querying data"
        case "request_user_input":
            return "Waiting for input"
        case "multi_tool_use.parallel":
            return "Using tools"
        case "":
            return "Using tool"
        default:
            if toolName?.localizedCaseInsensitiveContains("search") == true {
                return "Searching"
            }
            if toolName?.localizedCaseInsensitiveContains("read") == true {
                return "Reading"
            }
            if toolName?.localizedCaseInsensitiveContains("write") == true ||
                toolName?.localizedCaseInsensitiveContains("edit") == true {
                return "Editing"
            }
            return "Using tool"
        }
    }

    public static func label(forMCPServer server: String?, toolName: String?) -> String {
        switch server ?? "" {
        case "node_repl":
            return label(forToolName: toolName ?? "js")
        case "tool_search":
            return "Searching tools"
        case "codex_apps":
            return "Using app"
        case "":
            return label(forToolName: toolName)
        default:
            return "Using MCP"
        }
    }

    public static func reviewLabel(after label: String?) -> String {
        switch label {
        case "Editing":
            return "Reviewing edits"
        case "Running command", "Sending input", "Running JS":
            return "Reviewing output"
        case "Searching web", "Searching tools", "Searching files":
            return "Reading results"
        case "Viewing image":
            return "Inspecting image"
        case "Creating image":
            return "Inspecting image"
        case "Reading", "Reading email", "Querying data":
            return "Reviewing data"
        case "Using app":
            return "Checking app"
        default:
            return "Reasoning"
        }
    }
}
