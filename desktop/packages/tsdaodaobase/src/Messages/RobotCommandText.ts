import { MessageContent, MessageContentType } from "wukongimjssdk";

/** Text payload with bot_command entity + robot_id (aligns with iOS WKMessageEntity). */
export class RobotCommandText extends MessageContent {
  text: string = "";
  robotID: string = "";

  constructor(text?: string, robotID?: string) {
    super();
    if (text) this.text = text;
    if (robotID) this.robotID = robotID;
  }

  decodeJSON(content: any) {
    this.text = content?.content || "";
    this.robotID = content?.robot_id || "";
  }

  encodeJSON() {
    const cmd = this.text || "";
    const json: any = {
      content: cmd,
      entities: [
        {
          type: "bot_command",
          offset: 0,
          length: cmd.length,
        },
      ],
    };
    if (this.robotID) {
      json.robot_id = this.robotID;
    }
    return json;
  }

  get contentType() {
    return MessageContentType.text;
  }

  get conversationDigest() {
    return (this.text || "").replace(/\n/g, " ");
  }
}
