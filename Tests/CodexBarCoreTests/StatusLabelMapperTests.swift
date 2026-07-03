import Testing
@testable import CodexBarCore

@Suite
struct StatusLabelMapperTests {
    @Test
    func mapsKnownFunctionTools() {
        #expect(StatusLabelMapper.label(forToolName: "exec_command") == "Running command")
        #expect(StatusLabelMapper.label(forToolName: "write_stdin") == "Sending input")
        #expect(StatusLabelMapper.label(forToolName: "apply_patch") == "Editing")
        #expect(StatusLabelMapper.label(forToolName: "read_mcp_resource") == "Reading")
        #expect(StatusLabelMapper.label(forToolName: "web_search") == "Searching web")
        #expect(StatusLabelMapper.label(forToolName: "tool_search_tool") == "Searching tools")
        #expect(StatusLabelMapper.label(forToolName: "rg") == "Searching files")
        #expect(StatusLabelMapper.label(forToolName: "imagegen") == "Creating image")
        #expect(StatusLabelMapper.label(forToolName: "view_image") == "Viewing image")
        #expect(StatusLabelMapper.label(forToolName: "js") == "Running JS")
        #expect(StatusLabelMapper.label(forToolName: "update_plan") == "Planning")
        #expect(StatusLabelMapper.label(forToolName: "get_goal") == "Checking goal")
        #expect(StatusLabelMapper.label(forToolName: "create_goal") == "Updating goal")
        #expect(StatusLabelMapper.label(forToolName: "click") == "Using app")
        #expect(StatusLabelMapper.label(forToolName: "_read_email_thread") == "Reading email")
        #expect(StatusLabelMapper.label(forToolName: "_execute_sql") == "Querying data")
        #expect(StatusLabelMapper.label(forToolName: "request_user_input") == "Waiting for input")
        #expect(StatusLabelMapper.label(forToolName: "multi_tool_use.parallel") == "Using tools")
    }

    @Test
    func mapsFuzzyAndUnknownFunctionTools() {
        #expect(StatusLabelMapper.label(forToolName: nil) == "Using tool")
        #expect(StatusLabelMapper.label(forToolName: "") == "Using tool")
        #expect(StatusLabelMapper.label(forToolName: "semantic_search") == "Searching")
        #expect(StatusLabelMapper.label(forToolName: "read_project") == "Reading")
        #expect(StatusLabelMapper.label(forToolName: "bulk_write") == "Editing")
        #expect(StatusLabelMapper.label(forToolName: "totally_custom") == "Using tool")
    }

    @Test
    func mapsMCPServers() {
        #expect(StatusLabelMapper.label(forMCPServer: "node_repl", toolName: "js") == "Running JS")
        #expect(StatusLabelMapper.label(forMCPServer: "tool_search", toolName: "tool_search_tool") == "Searching tools")
        #expect(StatusLabelMapper.label(forMCPServer: "codex_apps", toolName: "click") == "Using app")
        #expect(StatusLabelMapper.label(forMCPServer: "", toolName: "apply_patch") == "Editing")
        #expect(StatusLabelMapper.label(forMCPServer: "unknown", toolName: "apply_patch") == "Using MCP")
    }

    @Test
    func mapsReviewLabels() {
        #expect(StatusLabelMapper.reviewLabel(after: "Editing") == "Reviewing edits")
        #expect(StatusLabelMapper.reviewLabel(after: "Running command") == "Reviewing output")
        #expect(StatusLabelMapper.reviewLabel(after: "Searching web") == "Reading results")
        #expect(StatusLabelMapper.reviewLabel(after: "Viewing image") == "Inspecting image")
        #expect(StatusLabelMapper.reviewLabel(after: "Reading") == "Reviewing data")
        #expect(StatusLabelMapper.reviewLabel(after: "Using app") == "Checking app")
        #expect(StatusLabelMapper.reviewLabel(after: nil) == "Reasoning")
    }
}
