/**
 * MyStreamTV - Administrative Console Logic
 * Handles dynamic channel management and content discovery triggers.
 */

const API_BASE = '/api/channels';
let currentChannels = [];

document.addEventListener('DOMContentLoaded', () => {
    loadChannels();
    setupEventListeners();
});

function setupEventListeners() {
    // Add Channel
    document.getElementById('add-channel-btn').addEventListener('click', () => {
        openEditor();
    });

    // Reload Engine
    document.getElementById('reload-pool-btn').addEventListener('click', async () => {
        const btn = document.getElementById('reload-pool-btn');
        btn.textContent = 'RELOADING...';
        btn.disabled = true;

        try {
            await fetch(`${API_BASE}/reload`, { method: 'POST' });
            alert('Discovery engine started in background. The content pool is being expanded.');
        } catch (e) {
            console.error(e);
        } finally {
            btn.textContent = 'RELOAD_ENGINE';
            btn.disabled = false;
        }
    });

    // Close Editor
    document.getElementById('cancel-btn').addEventListener('click', closeEditor);
    document.getElementById('editor-overlay').addEventListener('click', (e) => {
        if (e.target.id === 'editor-overlay') closeEditor();
    });

    // Form Submit
    document.getElementById('channel-form').addEventListener('submit', handleFormSubmit);

    // Add Slot
    document.getElementById('add-slot-btn').addEventListener('click', () => {
        addSlotRow();
    });
}

async function loadChannels() {
    const listContainer = document.getElementById('channel-list');

    try {
        const response = await fetch(API_BASE);
        currentChannels = await response.json();

        listContainer.innerHTML = '';
        currentChannels.forEach(channel => {
            const card = createChannelCard(channel);
            listContainer.appendChild(card);
        });
    } catch (e) {
        listContainer.innerHTML = `<div class="error">ERROR_CONNECTING_TO_BACKEND: ${e.message}</div>`;
    }
}

function createChannelCard(channel) {
    const card = document.createElement('div');
    card.className = `channel-card ${channel.enabled ? '' : 'disabled'}`;
    card.innerHTML = `
        <h3>${channel.icon || '📺'} ${channel.name}</h3>
        <p class="meta">ID: ${channel.id} | Slots: ${channel.slots?.length || 0}</p>
        <p style="font-size: 0.8rem; height: 3em; overflow: hidden;">${channel.description || 'No description.'}</p>
        <div class="actions">
            <button class="btn btn-sm btn-edit" onclick="event.stopPropagation(); editChannel('${channel.id}')">EDIT</button>
            <button class="btn btn-sm" onclick="event.stopPropagation(); toggleChannel('${channel.id}', ${!channel.enabled})">
                ${channel.enabled ? 'DISABLE' : 'ENABLE'}
            </button>
            <button class="btn btn-sm btn-danger" onclick="event.stopPropagation(); deleteChannel('${channel.id}')">DEL</button>
        </div>
    `;
    card.onclick = () => editChannel(channel.id);
    return card;
}

function openEditor(channel = null) {
    const overlay = document.getElementById('editor-overlay');
    const form = document.getElementById('channel-form');
    const title = document.getElementById('editor-title');

    form.reset();
    document.getElementById('slots-list').innerHTML = '';

    if (channel) {
        title.textContent = `EDIT_CHANNEL: ${channel.id}`;
        document.getElementById('field-id').value = channel.id;
        document.getElementById('field-name').value = channel.name;
        document.getElementById('field-icon').value = channel.icon;
        document.getElementById('field-priority').value = channel.priority;
        document.getElementById('field-description').value = channel.description || '';

        channel.slots.forEach(slot => addSlotRow(slot));
    } else {
        title.textContent = 'CREATE_NEW_CHANNEL';
        document.getElementById('field-id').value = '';
        addSlotRow(); // Start with one empty slot
    }

    overlay.style.display = 'block';
    document.body.style.overflow = 'hidden';
}

function closeEditor() {
    document.getElementById('editor-overlay').style.display = 'none';
    document.body.style.overflow = 'auto';
}

function addSlotRow(slot = null) {
    const container = document.getElementById('slots-list');
    const row = document.createElement('div');
    row.className = 'slot-card';

    row.innerHTML = `
        <div style="display: grid; grid-template-columns: 1fr 1fr 2fr; gap: 0.5rem; margin-bottom: 0.5rem;">
            <input type="time" class="slot-start" value="${slot?.start || '00:00'}">
            <input type="time" class="slot-end" value="${slot?.end || '04:00'}">
            <input type="text" class="slot-label" placeholder="Slot Label" value="${slot?.label || ''}">
        </div>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem;">
            <select class="slot-type">
                <option value="movie" ${slot?.content_type === 'movie' ? 'selected' : ''}>Movies Only</option>
                <option value="tv" ${slot?.content_type === 'tv' ? 'selected' : ''}>TV Series Only</option>
            </select>
            <input type="text" class="slot-universes" placeholder="Universes (Star Wars, Marvel...)" value="${slot?.universes?.join(', ') || ''}">
        </div>
        <button type="button" class="btn btn-danger btn-sm" style="position: absolute; top: 5px; right: 5px; padding: 2px 5px;" onclick="this.parentElement.remove()">×</button>
    `;
    container.appendChild(row);
}

async function handleFormSubmit(e) {
    e.preventDefault();

    const id = document.getElementById('field-id').value;
    const isEdit = !!id;

    // Gather slot data
    const slotRows = document.querySelectorAll('.slot-card');
    const slots = Array.from(slotRows).map(row => ({
        start: row.querySelector('.slot-start').value,
        end: row.querySelector('.slot-end').value,
        label: row.querySelector('.slot-label').value,
        content_type: row.querySelector('.slot-type').value,
        universes: row.querySelector('.slot-universes').value.split(',').map(u => u.trim()).filter(u => u)
    }));

    const channelData = {
        name: document.getElementById('field-name').value,
        icon: document.getElementById('field-icon').value,
        priority: parseInt(document.getElementById('field-priority').value),
        description: document.getElementById('field-description').value,
        day_of_week: 0, // Default to Sunday or handle properly
        enabled: true,
        slots: slots
    };

    if (isEdit) channelData.id = id;

    try {
        const method = isEdit ? 'PUT' : 'POST';
        const url = isEdit ? `${API_BASE}/${id}` : API_BASE;

        const response = await fetch(url, {
            method: method,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(channelData)
        });

        if (response.ok) {
            closeEditor();
            loadChannels();
        } else {
            alert('Error saving channel. Check console.');
        }
    } catch (err) {
        console.error(err);
    }
}

window.editChannel = function (id) {
    const channel = currentChannels.find(c => c.id === id);
    if (channel) openEditor(channel);
}

window.deleteChannel = async function (id) {
    if (!confirm(`Are you sure you want to delete channel ${id}?`)) return;

    try {
        await fetch(`${API_BASE}/${id}`, { method: 'DELETE' });
        loadChannels();
    } catch (e) {
        console.error(e);
    }
}

window.toggleChannel = async function (id, enabled) {
    try {
        await fetch(`${API_BASE}/${id}/toggle`, { method: 'PATCH' });
        loadChannels();
    } catch (e) {
        console.error(e);
    }
}
