// MyStreamTV - Vanilla JavaScript EPG Application

const API_BASE = '/api/epg'; // Relative URL works with any port
const TMDB_IMAGE_BASE = 'https://image.tmdb.org/t/p';
const MINUTE_WIDTH = 4; // pixels per minute

// State
let guideData = null;
let position = { channelIndex: 0, programIndex: 0 };
let modalOpen = false;
let selectedProgram = null;

// DOM Elements
const elements = {
    loading: null,
    error: null,
    epgContainer: null,
    channelList: null,
    timeRuler: null,
    programGrid: null,
    nowLine: null,
    backdrop: null,
    modal: null,
    modalClose: null,
    modalTitle: null,
    modalMeta: null,
    modalOverview: null,
    modalProviders: null,
    modalBackdrop: null,
    currentTime: null,
    currentDate: null,
};

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    // Cache DOM elements
    elements.loading = document.getElementById('loading');
    elements.error = document.getElementById('error');
    elements.epgContainer = document.getElementById('epg-container');
    elements.channelList = document.getElementById('channel-list');
    elements.timeRuler = document.getElementById('time-ruler');
    elements.programGrid = document.getElementById('program-grid');
    elements.nowLine = document.getElementById('now-line');
    elements.backdrop = document.getElementById('backdrop');
    elements.modal = document.getElementById('modal');
    elements.modalClose = document.getElementById('modal-close');
    elements.modalTitle = document.getElementById('modal-title');
    elements.modalMeta = document.getElementById('modal-meta');
    elements.modalOverview = document.getElementById('modal-overview');
    elements.modalProviders = document.getElementById('modal-providers');
    elements.modalBackdrop = document.getElementById('modal-backdrop');
    elements.currentTime = document.getElementById('current-time');
    elements.currentDate = document.getElementById('current-date');

    // Event listeners
    document.addEventListener('keydown', handleKeyDown);
    elements.modalClose.addEventListener('click', closeModal);
    elements.modal.addEventListener('click', (e) => {
        if (e.target === elements.modal) closeModal();
    });

    // Update time every second
    updateClock();
    setInterval(updateClock, 1000);

    // Load guide data
    loadGuide();

    // Synchronize scrolling
    elements.programGrid.addEventListener('scroll', () => {
        elements.channelList.scrollTop = elements.programGrid.scrollTop;
        elements.timeRuler.scrollLeft = elements.programGrid.scrollLeft;
    });
});

// ======================== DATA LOADING ========================

async function loadGuide() {
    showLoading();

    try {
        const response = await fetch(`${API_BASE}/guide?hours=6`);

        if (!response.ok) {
            throw new Error(`HTTP error: ${response.status}`);
        }

        guideData = await response.json();
        renderGuide();
        showEPG();

        // Auto-refresh every 5 minutes
        setTimeout(loadGuide, 5 * 60 * 1000);

    } catch (err) {
        console.error('Failed to load guide:', err);
        showError();
    }
}

async function loadProviders(tmdbId, contentType = 'movie') {
    try {
        const response = await fetch(`${API_BASE}/program/${tmdbId}/providers?content_type=${contentType}`);
        if (!response.ok) throw new Error('Failed to load providers');
        return await response.json();
    } catch (err) {
        console.error('Failed to load providers:', err);
        return { providers: [] };
    }
}

// ======================== RENDERING ========================

function renderGuide() {
    if (!guideData) return;

    renderChannels();
    renderTimeRuler();
    renderPrograms();
    updateNowLine();
    updateFocus();
}

function renderChannels() {
    elements.channelList.innerHTML = '';

    guideData.guide.forEach((channelGuide, idx) => {
        const channel = channelGuide.channel;
        const div = document.createElement('div');
        div.className = `channel-item ${idx === position.channelIndex ? 'active' : ''}`;
        div.innerHTML = `
            <span class="channel-icon">${channel.icon}</span>
            <span class="channel-name">${channel.name}</span>
        `;
        elements.channelList.appendChild(div);
    });
}

function renderTimeRuler() {
    elements.timeRuler.innerHTML = '';

    const startTime = new Date(guideData.start_time);
    startTime.setMinutes(0, 0, 0);

    // Generate 12 half-hour marks (6 hours)
    for (let i = 0; i < 12; i++) {
        const time = new Date(startTime.getTime() + i * 30 * 60 * 1000);
        const isHour = time.getMinutes() === 0;

        const div = document.createElement('div');
        div.className = `time-mark ${isHour ? 'hour' : ''}`;
        div.textContent = formatTime(time);
        elements.timeRuler.appendChild(div);
    }
}

function renderPrograms() {
    // Clear existing rows (keep now-line)
    const rows = elements.programGrid.querySelectorAll('.program-row');
    rows.forEach(row => row.remove());

    const currentTime = new Date();

    guideData.guide.forEach((channelGuide, channelIdx) => {
        const row = document.createElement('div');
        row.className = 'program-row';
        row.dataset.channelIndex = channelIdx;

        channelGuide.programs.forEach((program, progIdx) => {
            const card = createProgramCard(program, channelIdx, progIdx, currentTime);
            row.appendChild(card);
        });

        elements.programGrid.appendChild(row);
    });
}

function createProgramCard(program, channelIdx, progIdx, currentTime) {
    const card = document.createElement('div');
    const width = Math.max(120, program.runtime_minutes * MINUTE_WIDTH);

    const startTime = new Date(program.start_time);
    const endTime = new Date(program.end_time);
    const isNowPlaying = currentTime >= startTime && currentTime < endTime;
    const isFocused = channelIdx === position.channelIndex && progIdx === position.programIndex;

    card.className = `program-card ${isNowPlaying ? 'now-playing' : ''} ${isFocused ? 'focused' : ''}`;
    card.style.width = `${width}px`;
    card.dataset.channelIndex = channelIdx;
    card.dataset.programIndex = progIdx;
    card.tabIndex = isFocused ? 0 : -1;

    // Poster thumbnail (small, on the right)
    const posterHtml = program.poster_path
        ? `<img class="program-poster" src="${TMDB_IMAGE_BASE}/w92${program.poster_path}" alt="">`
        : '';

    card.innerHTML = `
        ${posterHtml}
        <div class="program-info">
            <div class="program-genre">${program.slot_label || 'Programación'}</div>
            <div class="program-title">${program.title}</div>
            <div class="program-meta">
                ${program.release_year ? program.release_year + ' • ' : ''}
                ${program.runtime_minutes} min
                ${program.vote_average > 0 ? ' • ★ ' + program.vote_average.toFixed(1) : ''}
            </div>
            <div class="program-time">${formatTime(startTime)} - ${formatTime(endTime)}</div>
        </div>
    `;

    card.addEventListener('click', () => {
        position.channelIndex = channelIdx;
        position.programIndex = progIdx;
        updateFocus();
        openModal(program);
    });

    return card;
}

function updateNowLine() {
    if (!guideData) return;

    const now = new Date();
    const startTime = new Date(guideData.start_time);
    const diffMinutes = (now.getTime() - startTime.getTime()) / (1000 * 60);

    if (diffMinutes > 0) {
        elements.nowLine.style.left = `${diffMinutes * MINUTE_WIDTH}px`;
        elements.nowLine.style.display = 'block';
    } else {
        elements.nowLine.style.display = 'none';
    }
}

// ======================== NAVIGATION ========================

function handleKeyDown(e) {
    if (modalOpen) {
        if (e.key === 'Escape') {
            e.preventDefault();
            closeModal();
        }
        return;
    }

    switch (e.key) {
        case 'ArrowUp':
            e.preventDefault();
            moveUp();
            break;
        case 'ArrowDown':
            e.preventDefault();
            moveDown();
            break;
        case 'ArrowLeft':
            e.preventDefault();
            moveLeft();
            break;
        case 'ArrowRight':
            e.preventDefault();
            moveRight();
            break;
        case 'Enter':
        case ' ':
            e.preventDefault();
            selectProgram();
            break;
    }
}

function moveUp() {
    if (position.channelIndex > 0) {
        position.channelIndex--;
        position.programIndex = Math.min(position.programIndex, getProgramCount(position.channelIndex) - 1);
        updateFocus();
    }
}

function moveDown() {
    if (guideData && position.channelIndex < guideData.guide.length - 1) {
        position.channelIndex++;
        position.programIndex = Math.min(position.programIndex, getProgramCount(position.channelIndex) - 1);
        updateFocus();
    }
}

function moveLeft() {
    if (position.programIndex > 0) {
        position.programIndex--;
        updateFocus();
    }
}

function moveRight() {
    const maxPrograms = getProgramCount(position.channelIndex);
    if (position.programIndex < maxPrograms - 1) {
        position.programIndex++;
        updateFocus();
    }
}

function selectProgram() {
    const program = getCurrentProgram();
    if (program) {
        openModal(program);
    }
}

function getProgramCount(channelIndex) {
    if (!guideData || !guideData.guide[channelIndex]) return 0;
    return guideData.guide[channelIndex].programs.length;
}

function getCurrentProgram() {
    if (!guideData) return null;
    return guideData.guide[position.channelIndex]?.programs[position.programIndex];
}

function updateFocus() {
    // Update channel list
    const channelItems = elements.channelList.querySelectorAll('.channel-item');
    channelItems.forEach((item, idx) => {
        item.classList.toggle('active', idx === position.channelIndex);
    });

    // Update program cards
    const allCards = elements.programGrid.querySelectorAll('.program-card');
    allCards.forEach(card => {
        const chIdx = parseInt(card.dataset.channelIndex);
        const prIdx = parseInt(card.dataset.programIndex);
        const isFocused = chIdx === position.channelIndex && prIdx === position.programIndex;
        card.classList.toggle('focused', isFocused);
        card.tabIndex = isFocused ? 0 : -1;
    });

    // Scroll focused card into view
    const focusedCard = elements.programGrid.querySelector('.program-card.focused');
    if (focusedCard) {
        focusedCard.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
    }

    // Sync channel list scroll
    const activeChannel = elements.channelList.querySelector('.channel-item.active');
    if (activeChannel) {
        activeChannel.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }

    // Update backdrop
    updateBackdrop();
}

function updateBackdrop() {
    const program = getCurrentProgram();
    if (program && program.backdrop_path) {
        const url = `${TMDB_IMAGE_BASE}/w1280${program.backdrop_path}`;
        elements.backdrop.style.backgroundImage = `url(${url})`;
        elements.backdrop.style.opacity = '0.15';
    } else {
        elements.backdrop.style.opacity = '0';
    }
}

// ======================== MODAL ========================

async function openModal(program) {
    selectedProgram = program;
    modalOpen = true;

    // Set content
    elements.modalTitle.textContent = program.title;

    const startTime = new Date(program.start_time);
    const endTime = new Date(program.end_time);
    elements.modalMeta.innerHTML = `
        ${program.release_year ? `<span>${program.release_year}</span>` : ''}
        <span>${program.runtime_minutes} min</span>
        <span>${formatTime(startTime)} - ${formatTime(endTime)}</span>
        ${program.vote_average > 0 ? `<span class="modal-rating">★ ${program.vote_average.toFixed(1)}</span>` : ''}
    `;

    elements.modalOverview.textContent = program.overview || 'Sin descripción disponible.';

    // Set backdrop
    if (program.backdrop_path) {
        elements.modalBackdrop.style.backgroundImage = `url(${TMDB_IMAGE_BASE}/w1280${program.backdrop_path})`;
    } else {
        elements.modalBackdrop.style.backgroundImage = 'none';
    }

    // Show modal
    elements.modal.style.display = 'flex';

    // Load providers
    elements.modalProviders.innerHTML = '<span style="color: var(--epg-text-dim)">Cargando plataformas...</span>';

    const data = await loadProviders(program.tmdb_id, program.content_type);

    if (data.providers && data.providers.length > 0) {
        elements.modalProviders.innerHTML = data.providers.map(provider => `
            <a href="${provider.deep_link || '#'}" 
               target="_blank" 
               class="btn-tune"
               ${!provider.deep_link ? 'onclick="event.preventDefault()"' : ''}>
                ${provider.logo_path ? `<img src="${TMDB_IMAGE_BASE}/w45${provider.logo_path}" alt="">` : ''}
                Sintonizar en ${provider.provider_name}
            </a>
        `).join('');
    } else {
        elements.modalProviders.innerHTML = '<span style="color: var(--epg-text-dim)">No hay plataformas de streaming disponibles para este título en México.</span>';
    }
}

function closeModal() {
    modalOpen = false;
    selectedProgram = null;
    elements.modal.style.display = 'none';
}

// ======================== UTILITIES ========================

function formatTime(date) {
    return date.toLocaleTimeString('es-MX', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
    });
}

function updateClock() {
    const now = new Date();
    elements.currentTime.textContent = formatTime(now);
    elements.currentDate.textContent = now.toLocaleDateString('es-MX', {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
    });
}

function showLoading() {
    elements.loading.style.display = 'flex';
    elements.error.style.display = 'none';
    elements.epgContainer.style.display = 'none';
}

function showError() {
    elements.loading.style.display = 'none';
    elements.error.style.display = 'flex';
    elements.epgContainer.style.display = 'none';
}

function showEPG() {
    elements.loading.style.display = 'none';
    elements.error.style.display = 'none';
    elements.epgContainer.style.display = 'flex';
}

// Make loadGuide globally available for retry button
window.loadGuide = loadGuide;
