import React, { useState, useCallback } from 'react';
import { useDropzone } from 'react-dropzone';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Modal } from '@/components/ui/modal'; // Assuming Modal exists
import { Eye, Share, History, FileText, Image, File } from 'lucide-react'; // Assuming lucide-react icons

interface FileVersion {
  id: string;
  file: File;
  timestamp: Date;
}

interface FileItem {
  file: File;
  versions: FileVersion[];
  permissions: {
    isPublic: boolean;
    sharedWith: string[];
  };
}

interface FileUploadProps {
  onFilesUploaded: (files: File[]) => void;
  maxFiles?: number;
  acceptedFileTypes?: string;
  maxFileSize?: number;
}

export const FileUpload: React.FC<FileUploadProps> = ({
  onFilesUploaded,
  maxFiles = 10,
  acceptedFileTypes = 'image/*,application/pdf,.doc,.docx,.txt',
  maxFileSize = 10 * 1024 * 1024, // 10MB
}) => {
  const [uploadedFiles, setUploadedFiles] = useState<FileItem[]>([]);
  const [previews, setPreviews] = useState<string[]>([]);
  const [previewModal, setPreviewModal] = useState<{ open: boolean; src?: string; file?: File }>({ open: false });
  const [sharingModal, setSharingModal] = useState<{ open: boolean; index?: number }>({ open: false });
  const [versionModal, setVersionModal] = useState<{ open: boolean; index?: number }>({ open: false });

  const getFileIcon = (file: File) => {
    if (file.type.startsWith('image/')) return <Image className="w-10 h-10" />;
    if (file.type === 'application/pdf') return <FileText className="w-10 h-10" />;
    return <File className="w-10 h-10" />;
  };

  const handlePreview = (file: File, src?: string) => {
    if (src) {
      setPreviewModal({ open: true, src, file });
    } else {
      // For non-images, perhaps open in new tab or show text preview
      // For now, just alert
      alert('Preview not available for this file type');
    }
  };

  const handleShare = (index: number) => {
    setSharingModal({ open: true, index });
  };

  const handleVersion = (index: number) => {
    setVersionModal({ open: true, index });
  };

  const addVersion = (index: number, newFile: File) => {
    const updatedFiles = [...uploadedFiles];
    updatedFiles[index].versions.push({ id: crypto.randomUUID(), file: newFile, timestamp: new Date() });
    setUploadedFiles(updatedFiles);
  };

  const updatePermissions = (index: number, permissions: FileItem['permissions']) => {
    const updatedFiles = [...uploadedFiles];
    updatedFiles[index].permissions = permissions;
    setUploadedFiles(updatedFiles);
  };

  const onDrop = useCallback((acceptedFiles: File[]) => {
    // Wrap accepted files into FileItem with initial version and permissions
    const newFileItems: FileItem[] = acceptedFiles.map(file => ({
      file,
      versions: [{ id: crypto.randomUUID(), file, timestamp: new Date() }],
      permissions: { isPublic: false, sharedWith: [] }
    }));

    const combinedFiles = [...uploadedFiles, ...newFileItems].slice(0, maxFiles);
    setUploadedFiles(combinedFiles);
    onFilesUploaded(combinedFiles.map(item => item.file));

    // Generate previews for images
    const newPreviews = acceptedFiles
      .filter(file => file.type.startsWith('image/'))
      .map(file => URL.createObjectURL(file));
    setPreviews(prev => [...prev, ...newPreviews]);
  }, [uploadedFiles, maxFiles, onFilesUploaded]);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: acceptedFileTypes.split(',').reduce((acc, type) => {
      acc[type.trim()] = [];
      return acc;
    }, {} as Record<string, string[]>),
    maxSize: maxFileSize,
    multiple: true,
  });

  const removeFile = (index: number) => {
    const newFiles = uploadedFiles.filter((_, i) => i !== index);
    setUploadedFiles(newFiles);
    onFilesUploaded(newFiles.map(item => item.file));

    // Clean up preview URL
    if (previews[index]) {
      URL.revokeObjectURL(previews[index]);
      setPreviews(prev => prev.filter((_, i) => i !== index));
    }
  };

  return (
    <div className="w-full">
      <div
        {...getRootProps()}
        className={`border-2 border-dashed rounded-lg p-6 text-center cursor-pointer transition-colors ${
          isDragActive ? 'border-blue-500 bg-blue-50' : 'border-gray-300 hover:border-gray-400'
        }`}
      >
        <input {...getInputProps()} />
        {isDragActive ? (
          <p className="text-blue-600">Drop the files here...</p>
        ) : (
          <p className="text-gray-600">
            Drag & drop files here, or click to select files
            <br />
            <span className="text-sm">Max {maxFiles} files, up to {maxFileSize / (1024 * 1024)}MB each</span>
          </p>
        )}
      </div>

      {uploadedFiles.length > 0 && (
        <div className="mt-4">
          <h4 className="text-lg font-semibold mb-2">Uploaded Files</h4>
          <div className="space-y-2">
            {uploadedFiles.map((file, index) => (
              <Card key={index} className="p-4">
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-4">
                    {previews[index] ? (
                      <img src={previews[index]} alt={file.file.name} className="w-12 h-12 object-cover rounded" />
                    ) : (
                      getFileIcon(file.file)
                    )}
                    <div>
                      <p className="font-medium">{file.file.name}</p>
                      <p className="text-sm text-gray-500">{(file.file.size / 1024).toFixed(1)} KB</p>
                      <p className="text-xs text-gray-400">Versions: {file.versions.length}</p>
                    </div>
                  </div>
                  <div className="flex space-x-2">
                    <Button size="sm" variant="outline" onClick={() => handlePreview(file.file, previews[index])}>
                      <Eye className="w-4 h-4" />
                    </Button>
                    <Button size="sm" variant="outline" onClick={() => handleShare(index)}>
                      <Share className="w-4 h-4" />
                    </Button>
                    <Button size="sm" variant="outline" onClick={() => handleVersion(index)}>
                      <History className="w-4 h-4" />
                    </Button>
                    <Button size="sm" variant="destructive" onClick={() => removeFile(index)}>
                      &times;
                    </Button>
                  </div>
                </div>
              </Card>
            ))}
          </div>
        </div>
      )}

      {/* Preview Modal */}
      <Modal open={previewModal.open} onClose={() => setPreviewModal({ open: false })}>
        <div className="p-4">
          <h3 className="text-lg font-semibold mb-4">File Preview</h3>
          {previewModal.src && (
            <img src={previewModal.src} alt={previewModal.file?.name} className="max-w-full max-h-96" />
          )}
        </div>
      </Modal>

      {/* Sharing Modal */}
      <Modal open={sharingModal.open} onClose={() => setSharingModal({ open: false })}>
        <div className="p-4">
          <h3 className="text-lg font-semibold mb-4">Share File</h3>
          {sharingModal.index !== undefined && (
            <div className="space-y-4">
              <div>
                <label className="flex items-center">
                  <input
                    type="checkbox"
                    checked={uploadedFiles[sharingModal.index].permissions.isPublic}
                    onChange={(e) => updatePermissions(sharingModal.index, { ...uploadedFiles[sharingModal.index].permissions, isPublic: e.target.checked })}
                  />
                  <span className="ml-2">Make Public</span>
                </label>
              </div>
              <div>
                <label>Shared With (comma-separated emails):</label>
                <input
                  type="text"
                  value={uploadedFiles[sharingModal.index].permissions.sharedWith.join(', ')}
                  onChange={(e) => updatePermissions(sharingModal.index, { ...uploadedFiles[sharingModal.index].permissions, sharedWith: e.target.value.split(',').map(s => s.trim()) })}
                  className="w-full p-2 border rounded"
                />
              </div>
            </div>
          )}
        </div>
      </Modal>

      {/* Version Modal */}
      <Modal open={versionModal.open} onClose={() => setVersionModal({ open: false })}>
        <div className="p-4">
          <h3 className="text-lg font-semibold mb-4">File Versions</h3>
          {versionModal.index !== undefined && (
            <div className="space-y-2">
              {uploadedFiles[versionModal.index].versions.map((version, vIndex) => (
                <div key={version.id} className="p-2 border rounded">
                  <p>Version {vIndex + 1}: {version.file.name}</p>
                  <p className="text-sm text-gray-500">{version.timestamp.toLocaleString()}</p>
                </div>
              ))}
              <Button onClick={() => {
                // Simulate adding a new version
                const input = document.createElement('input');
                input.type = 'file';
                input.onchange = (e) => {
                  const files = (e.target as HTMLInputElement).files;
                  if (files && files[0]) {
                    addVersion(versionModal.index, files[0]);
                  }
                };
                input.click();
              }}>
                Add New Version
              </Button>
            </div>
          )}
        </div>
      </Modal>
    </div>
  );
};
