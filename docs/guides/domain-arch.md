# Friday Domain Architecture

## Overview
This document outlines the domain-driven design architecture for the Friday application, following clean architecture principles. The architecture is organized into distinct layers with clear responsibilities and boundaries.

## Domain Entities

### 1. User
Core user entity representing an authenticated user in the system.
```typescript
interface User {
    id: string;
    username: string;
    user_secret: string;
}
```

### 2. Document
Represents any file or document stored in the system.
```typescript
interface Document {
    id: string;
    name: string;
    mime_type: string;
    metadata: Record<string, any>;
    is_public: boolean;
    unique_name?: string;
}
```

### 3. Topic
Organizational unit for content grouping.
```typescript
interface Topic {
    id: string;
    name: string;
    icon: string;
}
```

### 4. Activity
Records user actions and system events.
```typescript
interface Activity {
    id: string;
    name: string;
    description: string;
    activity_schema: Record<string, any>;
    icon: string;
    color: string;
}
```

### 5. Moment
Captures point-in-time events with rich context.
```typescript
interface Moment {
    id: string;
    activity_id: string;
    data: Record<string, any>;
    timestamp: Date;
    note_id?: string;
}
```

### 6. Note
Text-based content with rich formatting.
```typescript
interface Note {
    id: string;
    content: string;
    attachment: {
        type: string;
        url: string;
    };
    processing_status: 'NOT_PROCESSED' | 'PENDING' | 'COMPLETED' | 'FAILED';
    enrichment_data: Record<string, any>;
}
```

### 7. Task
Actionable items with tracking.
```typescript
interface Task {
    id: string;
    content: string;
    status: 'todo' | 'in_progress' | 'done';
    priority: 'low' | 'medium' | 'high';
    due_date?: Date;
    tags: string[];
    parent_id?: string;
    topic_id?: string;
}
```

## Domain Services

### 1. UserService
```typescript
interface UserService {
    createUser(username: string): Promise<User>;
    getUser(id: string): Promise<User>;
    updateUserPreferences(id: string, preferences: UserPreferences): Promise<User>;
    deactivateUser(id: string): Promise<void>;
}
```

### 2. DocumentService
```typescript
interface DocumentService {
    createDocument(document: Document): Promise<Document>;
    getDocument(id: string): Promise<Document>;
    updateDocument(id: string, document: Partial<Document>): Promise<Document>;
    deleteDocument(id: string): Promise<void>;
    shareDocument(id: string, settings: SharingSettings): Promise<Document>;
    getDocumentContent(id: string): Promise<DocumentContent>;
}
```

### 3. TopicService
```typescript
interface TopicService {
    createTopic(topic: Topic): Promise<Topic>;
    getTopic(id: string): Promise<Topic>;
    updateTopic(id: string, topic: Partial<Topic>): Promise<Topic>;
    deleteTopic(id: string): Promise<void>;
    getTopicHierarchy(rootId?: string): Promise<Topic[]>;
    moveTopic(id: string, newParentId: string): Promise<Topic>;
}
```

### 4. ActivityService
```typescript
interface ActivityService {
    recordActivity(activity: Activity): Promise<Activity>;
    getActivity(id: string): Promise<Activity>;
    getActivitiesByActor(actorId: string): Promise<Activity[]>;
    getActivitiesByTarget(targetType: string, targetId: string): Promise<Activity[]>;
}
```

### 5. MomentService
```typescript
interface MomentService {
    captureMoment(moment: Moment): Promise<Moment>;
    getMoment(id: string): Promise<Moment>;
    updateMoment(id: string, moment: Partial<Moment>): Promise<Moment>;
    deleteMoment(id: string): Promise<void>;
    addAttachment(momentId: string, attachment: Attachment): Promise<Moment>;
}
```

### 6. NoteService
```typescript
interface NoteService {
    createNote(note: Note): Promise<Note>;
    getNote(id: string): Promise<Note>;
    updateNote(id: string, note: Partial<Note>): Promise<Note>;
    deleteNote(id: string): Promise<void>;
    getNoteVersion(id: string, version: number): Promise<Note>;
    addReference(noteId: string, reference: Reference): Promise<Note>;
}
```

### 7. TaskService
```typescript
interface TaskService {
    createTask(task: Task): Promise<Task>;
    getTask(id: string): Promise<Task>;
    updateTask(id: string, task: Partial<Task>): Promise<Task>;
    deleteTask(id: string): Promise<void>;
    updateTaskStatus(id: string, status: TaskStatus): Promise<Task>;
    assignTask(id: string, assigneeId: string): Promise<Task>;
    updateProgress(id: string, progress: TaskProgress): Promise<Task>;
}
```

## Infrastructure Interfaces

These interfaces define how the domain interacts with external systems and persistence:

### 1. Storage
```typescript
interface StorageProvider {
    // Document storage
    storeDocument(content: DocumentContent): Promise<string>; // Returns storage ID
    retrieveDocument(storageId: string): Promise<DocumentContent>;
    deleteDocument(storageId: string): Promise<void>;
    getStorageStats(): Promise<StorageStats>;
    
    // Attachment handling
    storeAttachment(content: Blob, metadata: AttachmentMetadata): Promise<string>;
    retrieveAttachment(storageId: string): Promise<Blob>;
    deleteAttachment(storageId: string): Promise<void>;
}
```

### 2. Authentication
```typescript
interface AuthenticationProvider {
    validateCredentials(credentials: UserCredentials): Promise<boolean>;
    generateToken(userId: string): Promise<string>;
    validateToken(token: string): Promise<string>; // Returns userId if valid
    revokeToken(token: string): Promise<void>;
}
```

### 3. Persistence
```typescript
interface Repository<T> {
    create(entity: T): Promise<T>;
    findById(id: string): Promise<T | null>;
    findMany(query: Query): Promise<T[]>;
    update(id: string, entity: Partial<T>): Promise<T>;
    delete(id: string): Promise<void>;
    transaction<R>(operations: (repo: Repository<T>) => Promise<R>): Promise<R>;
}

interface Query {
    filter?: Record<string, any>;
    sort?: Record<string, 'asc' | 'desc'>;
    page?: number;
    limit?: number;
}
```

### 4. Events
```typescript
interface EventBus {
    publish(event: DomainEvent): Promise<void>;
    subscribe(eventType: string, handler: EventHandler): void;
    unsubscribe(eventType: string, handler: EventHandler): void;
}

interface DomainEvent {
    type: string;
    payload: any;
    metadata: {
        timestamp: Date;
        actor?: string;
        correlationId?: string;
    };
}

type EventHandler = (event: DomainEvent) => Promise<void>;
```

### 5. Search
```typescript
interface SearchProvider {
    indexDocument(document: IndexableDocument): Promise<void>;
    search(query: SearchQuery): Promise<SearchResult[]>;
    deleteFromIndex(documentId: string): Promise<void>;
    updateIndex(documentId: string, updates: Partial<IndexableDocument>): Promise<void>;
}

interface SearchQuery {
    term: string;
    filters?: Record<string, any>;
    page?: number;
    limit?: number;
}

interface SearchResult {
    id: string;
    type: string;
    score: number;
    highlights: Record<string, string[]>;
    document: any;
}
```

## Domain Use Cases

Use cases encapsulate core business operations and orchestrate domain services:

### 1. Document Management
```typescript
interface CreateDocumentUseCase {
    execute(params: {
        content: DocumentContent;
        metadata: DocumentMetadata;
        sharing?: SharingSettings;
        owner: string;
    }): Promise<Document>;
}

interface ShareDocumentUseCase {
    execute(params: {
        documentId: string;
        sharing: SharingSettings;
        actor: string;
    }): Promise<Document>;
}

interface MoveDocumentUseCase {
    execute(params: {
        documentId: string;
        targetTopicId: string;
        actor: string;
    }): Promise<Document>;
}
```

### 2. Task Management
```typescript
interface AssignTaskUseCase {
    execute(params: {
        taskId: string;
        assigneeId: string;
        actor: string;
        priority?: TaskPriority;
        dueDate?: Date;
    }): Promise<Task>;
}

interface CompleteTaskUseCase {
    execute(params: {
        taskId: string;
        actor: string;
        completionNotes?: string;
    }): Promise<Task>;
}

interface CreateSubtaskUseCase {
    execute(params: {
        parentTaskId: string;
        subtask: Omit<Task, 'id' | 'createdAt' | 'updatedAt'>;
        actor: string;
    }): Promise<Task>;
}
```

### 3. Moment Capture
```typescript
interface CaptureMomentUseCase {
    execute(params: {
        moment: Omit<Moment, 'id' | 'createdAt' | 'updatedAt'>;
        attachments?: Array<{
            content: Blob;
            metadata: AttachmentMetadata;
        }>;
        actor: string;
    }): Promise<Moment>;
}

interface TagMomentUseCase {
    execute(params: {
        momentId: string;
        tags: string[];
        actor: string;
    }): Promise<Moment>;
}
```

### 4. Note Organization
```typescript
interface CreateNoteWithReferencesUseCase {
    execute(params: {
        note: Omit<Note, 'id' | 'createdAt' | 'updatedAt'>;
        references: Reference[];
        actor: string;
    }): Promise<Note>;
}

interface MoveNoteToTopicUseCase {
    execute(params: {
        noteId: string;
        topicId: string;
        actor: string;
    }): Promise<Note>;
}
```

### 5. Topic Organization
```typescript
interface ReorganizeTopicsUseCase {
    execute(params: {
        moves: Array<{
            topicId: string;
            newParentId?: string;
            newPosition: number;
        }>;
        actor: string;
    }): Promise<Topic[]>;
}

interface MergeTopicsUseCase {
    execute(params: {
        sourceTopicIds: string[];
        targetTopicId: string;
        strategy: 'move' | 'copy';
        actor: string;
    }): Promise<Topic>;
}
```

## Common Patterns

### 1. Response Formats
```typescript
interface PaginatedResponse<T> {
    items: T[];
    total: number;
    page: number;
    size: number;
    pages: number;
}

interface GenericResponse<T> {
    data: T;
    message: string;
}

interface StorageStats {
    used_bytes: number;
    total_bytes: number;
}

interface ErrorResponse {
    error: string;
    message: string;
    details?: Record<string, any>;
}
```

### 2. Implementation Guidelines

1. **Entity Creation**
   - All entities should use the types specified above
   - Timestamps should be in ISO format
   - IDs follow the specified type (string UUID or number)
   - Validate all required fields

2. **Repository Implementation**
   - Handle data transformation between layers
   - Implement proper error handling using ErrorResponse format
   - Maintain consistent response formats
   - Use proper typing for all methods

3. **Use Case Implementation**
   - Single responsibility principle
   - Input validation
   - Proper error handling
   - Consistent response formats

4. **Testing**
   - Unit tests for entities and use cases
   - Integration tests for repositories
   - E2E tests for critical flows
   - Mock data sources for testing

class UpdateUserProfileUseCase {
    execute(updates: UserProfileUpdate): Promise<User>;
}
```

### 2. Document Management
```typescript
class UploadDocumentUseCase {
    execute(file: File, options: DocumentOptions): Promise<Document>;
}

class ShareDocumentUseCase {
    execute(id: string, shareOptions: ShareOptions): Promise<ShareResult>;
}

class ListUserDocumentsUseCase {
    execute(filters: DocumentFilters): Promise<PaginatedResponse<Document>>;
}
```

### 3. Task Management
```typescript
class CreateTaskUseCase {
    execute(data: TaskCreate): Promise<Task>;
}

class UpdateTaskStatusUseCase {
    execute(id: string, status: TaskStatus): Promise<Task>;
}

class AssignTaskUseCase {
    execute(id: string, assigneeId: string): Promise<Task>;
}
```

[Additional use cases follow similar patterns for other business operations]

## Common Patterns

### 1. Response Wrappers
```typescript
interface PaginatedResponse<T> {
    items: T[];
    total: number;
    page: number;
    page_size: number;
    has_more: boolean;
}

interface GenericResponse<T> {
    data: T;
    message: string;
}
```

### 2. Error Handling
```typescript
class DomainError extends Error {
    constructor(
        message: string,
        public code: string,
        public status: number,
        public details?: Record<string, any>
    ) {
        super(message);
    }
}
```

### 3. Validation
```typescript
interface Validator<T> {
    validate(data: T): ValidationResult;
}

interface ValidationResult {
    isValid: boolean;
    errors?: ValidationError[];
}
```

## Implementation Guidelines

1. **Entity Creation**
   - All entities should have immutable IDs
   - Timestamps should be in UTC
   - Use strong typing for all properties
   - Include validation rules in entity definitions

2. **Repository Implementation**
   - Handle data transformation between layers
   - Implement caching strategies where appropriate
   - Handle error translation to domain errors
   - Maintain transaction boundaries

3. **Use Case Implementation**
   - Single responsibility principle
   - Input validation
   - Error handling
   - Logging and monitoring
   - Transaction management

4. **Testing**
   - Unit tests for entities and use cases
   - Integration tests for repositories
   - E2E tests for critical flows
   - Mock data sources for testing

## Data Transformation Patterns

### Current Approach: Model-Based Transformation

We currently handle data transformation within our model classes:

```dart
class TaskModel {
  // ... properties ...

  // Convert from JSON
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'].toString(),
      content: json['content'] as String,
      status: _parseStatus(json['status'] as String?),
      // ... other fields
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'status': _formatStatus(status),
      // ... other fields
    };
  }

  // Convert to domain entity
  Task toDomain() {
    return Task(
      id: id,
      content: content,
      status: status,
      // ... other fields
    );
  }
}
```

### Alternative: Separate Mapper Pattern

We considered but decided against a separate mapper pattern:

```dart
// This pattern was considered but not implemented
abstract class TaskMapper {
  Task toDomain(Map<String, dynamic> json);
  Map<String, dynamic> toJson(Task task);
  String formatStatus(TaskStatus status);
  TaskStatus parseStatus(String status);
}
```

### Why We Chose Model-Based Transformation

1. **Encapsulation**: Transformation logic lives with the data it transforms
2. **Reduced Complexity**: No need for additional mapper classes
3. **Clear Responsibility**: Models handle their own serialization
4. **Type Safety**: Transformation methods are part of the type they handle

### Best Practices

1. Keep transformation methods in model classes
2. Use static methods for utility functions
3. Handle null values gracefully
4. Document format requirements
5. Include validation in transformation

### Example: Task Status Transformation

```dart
class TaskModel {
  static String _formatStatus(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo: return 'todo';
      case TaskStatus.inProgress: return 'in_progress';
      case TaskStatus.done: return 'done';
    }
  }

  static TaskStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'in_progress': return TaskStatus.inProgress;
      case 'done': return TaskStatus.done;
      case 'todo':
      default: return TaskStatus.todo;
    }
  }
}
```
