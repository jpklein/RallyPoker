## RallyPoker
### A Planning Poker app for Rally SDK 2.0 written in CoffeeScript

Working with geographically-distributed teams, sizing meetings can often stretch into lengthy discussions because team members haven't taken the time to read, digest, and elaborate on stories presented for review. This app is intended to encourage asynchronous story review by gamifying the sizing process and socializing team members' participation.

Team members viewing this app will first see a list of stories queued up for review. Clicking on a story's name will display its description, notes, and attachments as well as the stream of messages in its discussion thread. Team members will be able to create new messages and cast their vote for the story's size by selecting from a deck of planning poker cards. The names and profile pictures of other team members who have already voted on the selected story will be displayed along with a face-down card. Using specially-coded discussion-thread messages, the app will allow team members to size stories in their own time, notifying users that they have completed their review without revealing their estimate to the rest of the team.

Rally users with access to the project that are not team members will be presented with the same interface, except for two important changes. While they will not be able to select from a deck to size the story, they will be able to flip the face-down cards of team members who have already cast their vote. Additionally, they will be able to assign a point value directly to the story once the team members' cards are revealed. This value will then be be displayed alongside the story's name in the app's story list.

<img src="https://raw.github.com/jpklein/RallyPoker/wireframes/TeamMember_v1.png" width="600" height="400" style="margin:2em 0 0 2em;border:1px solid #222">
