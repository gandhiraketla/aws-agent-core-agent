from bedrock_agentcore.tools.code_interpreter_client import CodeInterpreter
from strands import Agent, tool
import json
import pandas as pd
from typing import Dict, Any, List
from strands.models import BedrockModel
from bedrock_agentcore.runtime import BedrockAgentCoreApp

app = BedrockAgentCoreApp()
# Initialize the Code Interpreter within a supported AWS region.
code_client = CodeInterpreter('us-west-2')
code_client.start(session_timeout_seconds=1200)
#Define and configure the code interpreter tool
#Define and configure the code interpreter tool
@tool
def execute_python(code: str, description: str = "") -> str:
    """Execute Python code in the sandbox."""

    if description:
        code = f"# {description}\n{code}"

    #Print generated Code to be executed
    print(f"\n Generated Code: {code}")


    # Call the Invoke method and execute the generated code, within the initialized code interpreter session
    response = code_client.invoke("executeCode", {
        "code": code,
        "language": "python",
        "clearContext": False
    })
    for event in response["stream"]:
        return json.dumps(event["result"])
SYSTEM_PROMPT = """You are a helpful AI assistant that validates all answers through code execution using the tools provided. DO NOT Answer questions without using the tools

VALIDATION PRINCIPLES:
1. When making claims about code, algorithms, or calculations - write code to verify them
2. Use execute_python to test mathematical calculations, algorithms, and logic
3. Create test scripts to validate your understanding before giving answers
4. Always show your work with actual code execution
5. If uncertain, explicitly state limitations and validate what you can

APPROACH:
- If asked about a programming concept, implement it in code to demonstrate
- If asked for calculations, compute them programmatically AND show the code
- If implementing algorithms, include test cases to prove correctness
- Document your validation process for transparency
- The sandbox maintains state between executions, so you can refer to previous results

TOOL AVAILABLE:
- execute_python: Run Python code and see output

RESPONSE FORMAT: The execute_python tool returns a JSON response with:
- sessionId: The sandbox session ID
- id: Request ID
- isError: Boolean indicating if there was an error
- content: Array of content objects with type and text/data
- structuredContent: For code execution, includes stdout, stderr, exitCode, executionTime

For successful code execution, the output will be in content[0].text and also in structuredContent.stdout.
Check isError field to see if there was an error.

Be thorough, accurate, and always validate your answers when possible."""
model = BedrockModel(
    model_id="anthropic.claude-3-haiku-20240307-v1:0"
)
agent = Agent(
    model=model,
    tools=[execute_python],
    system_prompt=SYSTEM_PROMPT
)
#@app.entrypoint
def strands_agent_bedrock(payload):
    """
    Invoke the tech support agent with a given payload
    """
    #user_input = payload.get("prompt")
    response = agent(payload)
    return response.message['content'][0]['text']

# --------------------------
# CLI Test
# --------------------------
if __name__ == "__main__":
    #app.run()
    response = strands_agent_bedrock("1,300,red,blue,green")